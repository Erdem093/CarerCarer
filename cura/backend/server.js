require('dotenv').config();
const express = require('express');
const http = require('http');
const twilio = require('twilio');
const { OpenAI } = require('openai');

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const server = http.createServer(app);

const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// In-memory conversation state keyed by CallSid
const callState = new Map();

// ─── Health check ──────────────────────────────────────────────────────────

app.get('/health', (req, res) => res.json({ status: 'ok' }));

// ─── Initiate outbound check-in call ──────────────────────────────────────

app.post('/initiate-call', async (req, res) => {
  const { to, userId, context } = req.body;
  if (!to) return res.status(400).json({ error: 'Missing phone number' });

  try {
    const call = await twilioClient.calls.create({
      to,
      from: process.env.TWILIO_PHONE_NUMBER,
      url: `${process.env.PUBLIC_URL}/twiml?userId=${userId}&context=${context || 'adhoc'}`,
      statusCallback: `${process.env.PUBLIC_URL}/call-status`,
      statusCallbackMethod: 'POST',
    });

    console.log(`[Twilio] Outbound call initiated: ${call.sid}`);
    res.json({ callSid: call.sid });
  } catch (err) {
    console.error('[Twilio] Initiate call error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ─── Emergency call to contact ────────────────────────────────────────────

app.post('/emergency-call', async (req, res) => {
  const { to, userName, contactName, timestamp } = req.body;
  if (!to) return res.status(400).json({ error: 'Missing phone number' });

  try {
    const message = `Hello ${contactName}. This is Cura, the AI companion for ${userName}. `
      + `${userName} has triggered an emergency alert at ${new Date(timestamp).toLocaleTimeString('en-GB')}. `
      + `Please check on them as soon as possible.`;

    const call = await twilioClient.calls.create({
      to,
      from: process.env.TWILIO_PHONE_NUMBER,
      twiml: `<Response><Say voice="Polly.Amy">${message}</Say><Pause length="2"/><Hangup/></Response>`,
    });

    res.json({ callSid: call.sid });
  } catch (err) {
    console.error('[Twilio] Emergency call error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ─── TwiML: opening greeting + first gather ───────────────────────────────

app.post('/twiml', async (req, res) => {
  const { userId, context } = req.query;
  const callSid = req.body.CallSid;

  const greeting = await getCuraReply(
    [{ role: 'user', content: 'Greet me warmly to start the check-in. Under 20 words.' }],
    context || 'adhoc'
  );

  callState.set(callSid, {
    userId,
    context: context || 'adhoc',
    history: [{ role: 'assistant', content: greeting }],
  });

  res.type('text/xml').send(buildGatherTwiML(greeting, callSid));
});

// ─── /respond: receives Twilio speech, returns next TwiML ────────────────

app.post('/respond', async (req, res) => {
  const callSid = req.body.CallSid;
  const speechResult = req.body.SpeechResult || '';
  const confidence = parseFloat(req.body.Confidence || '0');

  const state = callState.get(callSid);
  if (!state) {
    return res.type('text/xml').send('<Response><Say>Sorry, something went wrong. Goodbye.</Say><Hangup/></Response>');
  }

  if (!speechResult || confidence < 0.3) {
    // Nothing heard — ask again
    const prompt = 'Gently ask the user to repeat what they said, or ask if they are still there.';
    const reply = await getCuraReply(state.history, state.context, prompt);
    return res.type('text/xml').send(buildGatherTwiML(reply, callSid));
  }

  console.log(`[Call ${callSid}] User: "${speechResult}"`);
  state.history.push({ role: 'user', content: speechResult });

  // Crisis check
  const lower = speechResult.toLowerCase();
  const crisisWords = ["chest pain", "can't breathe", "fallen", "stroke", "unconscious", "heart attack"];
  if (crisisWords.some(w => lower.includes(w))) {
    const reply = 'That sounds serious. Please call 999 immediately. I am alerting your emergency contact now. Take care.';
    state.history.push({ role: 'assistant', content: reply });
    callState.delete(callSid);
    return res.type('text/xml').send(
      `<Response><Say voice="Polly.Amy">${reply}</Say><Hangup/></Response>`
    );
  }

  const reply = await getCuraReply(state.history, state.context);
  state.history.push({ role: 'assistant', content: reply });
  console.log(`[Call ${callSid}] Cura: "${reply}"`);

  res.type('text/xml').send(buildGatherTwiML(reply, callSid));
});

// ─── Call status callback ─────────────────────────────────────────────────

app.post('/call-status', (req, res) => {
  const { CallSid, CallStatus } = req.body;
  console.log(`[Twilio] Call ${CallSid} status: ${CallStatus}`);
  if (['completed', 'failed', 'busy', 'no-answer'].includes(CallStatus)) {
    callState.delete(CallSid);
  }
  res.sendStatus(200);
});

// ─── Helpers ──────────────────────────────────────────────────────────────

function buildGatherTwiML(sayText, callSid) {
  const actionUrl = `${process.env.PUBLIC_URL}/respond`;
  // Escape XML special chars
  const safe = sayText
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');

  return `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Gather input="speech" action="${actionUrl}" method="POST" speechTimeout="auto" language="en-GB" enhanced="true">
    <Say voice="Polly.Amy">${safe}</Say>
  </Gather>
  <Say voice="Polly.Amy">I didn't catch that. Take care. Goodbye.</Say>
  <Hangup/>
</Response>`;
}

function buildSystemPrompt(context) {
  const today = new Date().toLocaleDateString('en-GB', {
    weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
  });

  const contexts = {
    morning: 'MORNING CHECK-IN: Gently assess sleep quality (ask for a score 1-10), any pain, mood.',
    afternoon: 'AFTERNOON CHECK-IN: Check how the day is going, energy levels.',
    evening: 'EVENING CHECK-IN: Review the day. Acknowledge their hard work. Ask if they have rested.',
    adhoc: 'GENERAL CONVERSATION: Be warm and responsive to whatever they need.',
  };

  return `You are Cura, a warm AI companion for unpaid elderly carers in the UK.
SAFETY RULES:
- NEVER diagnose, prescribe, or give medical treatment advice
- If user mentions chest pain, breathing problems, fallen, stroke: say to call 999 immediately.
- Keep responses under 50 words — this is a phone call
- Warm, simple British English for someone aged 60-80
- Ask only one question at a time
Today is ${today}.
${contexts[context] || contexts.adhoc}`;
}

async function getCuraReply(history, context, overridePrompt) {
  try {
    const messages = [
      { role: 'system', content: buildSystemPrompt(context) },
      ...history,
    ];
    if (overridePrompt) {
      messages.push({ role: 'user', content: overridePrompt });
    }

    const response = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      max_tokens: 150,
      messages,
    });
    return response.choices[0].message.content.trim();
  } catch (err) {
    console.error('[OpenAI] Error:', err.message);
    return 'Sorry, I had a little trouble there. How are you feeling today?';
  }
}

// ─── Start server ─────────────────────────────────────────────────────────

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Cura backend running on port ${PORT}`);
  console.log(`Public URL: ${process.env.PUBLIC_URL}`);
});
