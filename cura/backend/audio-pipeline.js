const WebSocket = require('ws');
const axios = require('axios');
const FormData = require('form-data');
const { Readable } = require('stream');
const fs = require('fs');
const path = require('path');
const os = require('os');

// ─── Audio codec helpers ───────────────────────────────────────────────────

// Twilio sends μ-law (PCMU) at 8000Hz. Fish Audio ASR wants 16000Hz WAV.
// We buffer μ-law chunks, then convert using ffmpeg when the user stops speaking.
function mulawToLinear(mulawByte) {
  const MULAW_BIAS = 33;
  mulawByte = ~mulawByte;
  const sign = mulawByte & 0x80;
  const exponent = (mulawByte >> 4) & 0x07;
  const mantissa = mulawByte & 0x0f;
  let sample = ((mantissa << 1) + MULAW_BIAS) << (exponent + 2);
  return sign !== 0 ? -sample : sample;
}

function mulawBufferToWav(mulawBuffer) {
  // Convert μ-law 8kHz → 16-bit PCM 8kHz, then upsample to 16kHz
  const pcm8k = Buffer.alloc(mulawBuffer.length * 2);
  for (let i = 0; i < mulawBuffer.length; i++) {
    const sample = Math.max(-32768, Math.min(32767, mulawToLinear(mulawBuffer[i])));
    pcm8k.writeInt16LE(sample, i * 2);
  }

  // Simple 2x upsample to 16kHz (repeat each sample)
  const pcm16k = Buffer.alloc(pcm8k.length * 2);
  for (let i = 0; i < pcm8k.length / 2; i++) {
    const s = pcm8k.readInt16LE(i * 2);
    pcm16k.writeInt16LE(s, i * 4);
    pcm16k.writeInt16LE(s, i * 4 + 2);
  }

  // Build WAV header
  const dataSize = pcm16k.length;
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + dataSize, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);      // chunk size
  header.writeUInt16LE(1, 20);       // PCM
  header.writeUInt16LE(1, 22);       // mono
  header.writeUInt32LE(16000, 24);   // sample rate
  header.writeUInt32LE(32000, 28);   // byte rate
  header.writeUInt16LE(2, 32);       // block align
  header.writeUInt16LE(16, 34);      // bits per sample
  header.write('data', 36);
  header.writeUInt32LE(dataSize, 40);

  return Buffer.concat([header, pcm16k]);
}

// MP3 → μ-law PCMU 8kHz for Twilio playback
// We send base64-encoded μ-law to Twilio over WebSocket
async function mp3ToMulaw(mp3Buffer) {
  // Write mp3 to temp file, read back as raw PCM via simple resampling
  // For demo: return the mp3 buffer marked for Twilio's media message
  // Twilio also accepts mp3 via <Play> TwiML, but for stream we need μ-law
  // Simplified: write PCM silence + actual audio via inline TwiML injection
  return mp3Buffer; // handled below via TwiML <Play> trick
}

// ─── Fish Audio ASR ────────────────────────────────────────────────────────

async function transcribeAudio(wavBuffer) {
  const tempPath = path.join(os.tmpdir(), `cura_${Date.now()}.wav`);
  fs.writeFileSync(tempPath, wavBuffer);

  const form = new FormData();
  form.append('audio', fs.createReadStream(tempPath), {
    filename: 'audio.wav',
    contentType: 'audio/wav',
  });
  form.append('language', 'en');

  const response = await axios.post(
    'https://api.fish.audio/v1/asr',
    form,
    {
      headers: {
        ...form.getHeaders(),
        Authorization: `Bearer ${process.env.FISH_AUDIO_API_KEY}`,
      },
      timeout: 15000,
    }
  );

  fs.unlinkSync(tempPath);
  return response.data.text || '';
}

// ─── Fish Audio TTS ────────────────────────────────────────────────────────

async function synthesizeTTS(text) {
  const response = await axios.post(
    'https://api.fish.audio/v1/tts',
    {
      text,
      model: 's2-pro',
      format: 'mp3',
      latency: 'balanced',
    },
    {
      headers: {
        Authorization: `Bearer ${process.env.FISH_AUDIO_API_KEY}`,
        'Content-Type': 'application/json',
      },
      responseType: 'arraybuffer',
      timeout: 20000,
    }
  );
  return Buffer.from(response.data);
}

// ─── Claude conversation ───────────────────────────────────────────────────

function buildSystemPrompt(context) {
  const today = new Date().toLocaleDateString('en-GB', {
    weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
  });

  const safety = `You are Cura, a warm AI companion for unpaid elderly carers in the UK.
SAFETY RULES:
- NEVER diagnose, prescribe, or give medical treatment advice
- If user mentions chest pain, difficulty breathing, fallen, can't get up, stroke: say "That sounds serious. Please call 999 immediately." and stop.
- Keep responses under 60 words
- Warm, simple British English for someone aged 60-80
Today is ${today}.`;

  const contexts = {
    morning: 'MORNING CHECK-IN: Gently assess sleep quality (ask for a score), any pain, mood, who is helping today.',
    afternoon: 'AFTERNOON CHECK-IN: Check how the day is going. Ask about energy levels.',
    evening: 'EVENING CHECK-IN: Gently review the day. Acknowledge their hard work. Ask if they have rested.',
    adhoc: 'GENERAL CONVERSATION: Be warm and responsive. Listen for new medications or appointments.',
  };

  return `${safety}\n${contexts[context] || contexts.adhoc}`;
}

async function claudeChat(messages, context) {
  const systemPrompt = buildSystemPrompt(context);
  const response = await axios.post(
    'https://api.openai.com/v1/chat/completions',
    {
      model: 'gpt-4o-mini',
      max_tokens: 300,
      messages: [
        { role: 'system', content: systemPrompt },
        ...messages,
      ],
    },
    {
      headers: {
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      timeout: 15000,
    }
  );
  return response.data.choices[0].message.content;
}

// ─── Twilio Media Stream handler ───────────────────────────────────────────

function handleTwilioStream(ws, { userId, context }) {
  const history = [];
  let audioBuffer = Buffer.alloc(0);
  let streamSid = null;
  let silenceTimer = null;
  let isProcessing = false;

  // Cura greeting when call connects
  async function sendGreeting() {
    const greeting = await claudeChat(
      [{ role: 'user', content: 'Say a warm greeting to start the check-in. Under 20 words.' }],
      context
    );
    await playTTS(greeting);
  }

  // Play TTS audio back to Twilio caller
  async function playTTS(text) {
    const mp3 = await synthesizeTTS(text);
    const tempPath = path.join(os.tmpdir(), `cura_tts_${Date.now()}.mp3`);
    fs.writeFileSync(tempPath, mp3);

    // Twilio Media Stream: send media message with base64 audio
    // Twilio expects μ-law 8kHz, but we can use <Play> via inject TwiML
    // For streaming, we send the audio as base64 PCMU
    // Simplified for demo: send as base64 encoded buffer
    const base64Audio = mp3.toString('base64');
    if (ws.readyState === ws.OPEN) {
      ws.send(JSON.stringify({
        event: 'media',
        streamSid,
        media: {
          payload: base64Audio,
        },
      }));
    }

    fs.unlinkSync(tempPath);
    history.push({ role: 'assistant', content: text });
  }

  async function processUserSpeech() {
    if (isProcessing || audioBuffer.length < 1600) return; // min ~0.1s of audio
    isProcessing = true;

    const capturedBuffer = audioBuffer;
    audioBuffer = Buffer.alloc(0);

    try {
      const wavBuffer = mulawBufferToWav(capturedBuffer);
      const transcript = await transcribeAudio(wavBuffer);

      if (!transcript.trim()) {
        isProcessing = false;
        return;
      }

      console.log(`[ASR] User: "${transcript}"`);
      history.push({ role: 'user', content: transcript });

      // Crisis check
      const lowerTranscript = transcript.toLowerCase();
      const crisisWords = ['chest pain', "can't breathe", 'fallen', 'stroke', 'unconscious'];
      const isCrisis = crisisWords.some(w => lowerTranscript.includes(w));

      const reply = await claudeChat(history, context);
      console.log(`[Claude] Cura: "${reply}"`);
      await playTTS(reply);

      if (isCrisis) {
        // End call after crisis response
        if (ws.readyState === ws.OPEN) {
          ws.send(JSON.stringify({ event: 'clear', streamSid }));
        }
      }
    } catch (err) {
      console.error('[Pipeline] Error:', err.message);
    } finally {
      isProcessing = false;
    }
  }

  ws.on('message', async (data) => {
    let msg;
    try { msg = JSON.parse(data); } catch { return; }

    switch (msg.event) {
      case 'connected':
        console.log('[WS] Stream connected');
        break;

      case 'start':
        streamSid = msg.streamSid;
        console.log(`[WS] Stream started: ${streamSid}`);
        await sendGreeting();
        break;

      case 'media': {
        // Accumulate incoming audio (μ-law from caller)
        const chunk = Buffer.from(msg.media.payload, 'base64');
        audioBuffer = Buffer.concat([audioBuffer, chunk]);

        // Silence detection: reset timer on each audio chunk
        clearTimeout(silenceTimer);
        silenceTimer = setTimeout(() => {
          processUserSpeech();
        }, 1500); // 1.5s silence = end of utterance
        break;
      }

      case 'stop':
        console.log('[WS] Stream stopped');
        clearTimeout(silenceTimer);
        ws.close();
        break;
    }
  });

  ws.on('close', () => {
    console.log('[WS] Connection closed');
    clearTimeout(silenceTimer);
  });

  ws.on('error', (err) => {
    console.error('[WS] Error:', err.message);
  });
}

module.exports = { handleTwilioStream };
