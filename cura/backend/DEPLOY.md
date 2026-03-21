# Backend Deploy

This backend is required for Twilio calling and media-stream handling. Supabase
does not replace it on its own because this service:

- initiates Twilio calls with secret credentials
- serves TwiML webhooks
- receives Twilio status callbacks
- handles the live WebSocket media stream

## Recommended host

Render is the simplest option for this repo because the checked-in
[`render.yaml`](/Users/erdem/Projects/App_Tests/render.yaml) can create the
service directly from GitHub.

## Deploy steps

1. Push this repo to GitHub.
2. In Render, choose `New +` -> `Blueprint`.
3. Select the repo and approve the `render.yaml`.
4. Set these environment variables in Render:
   - `PUBLIC_URL`
   - `TWILIO_ACCOUNT_SID`
   - `TWILIO_AUTH_TOKEN`
   - `TWILIO_PHONE_NUMBER`
   - `FISH_AUDIO_API_KEY`
   - `CLAUDE_API_KEY`
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_KEY`
5. Deploy.

## App update after deploy

Once Render gives you a URL like:

```text
https://cura-backend.onrender.com
```

set the Flutter app backend URL to that value:

- in `cura/.env`, set `BACKEND_URL=https://cura-backend.onrender.com`
- or in the in-app debug field on the schedule screen, paste that URL

## Webhooks

Your backend uses `PUBLIC_URL` for these Twilio callbacks:

- `/twiml`
- `/call-status`
- `/stream` (via `wss://`)

Set `PUBLIC_URL` to the full Render URL so Twilio can reach the service.
