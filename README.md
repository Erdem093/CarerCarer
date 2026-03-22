# CarerCarer

CarerCarer is a voice-first support app for unpaid elderly carers in the UK. Inside the product, the AI assistant persona is called `Cura`.

The project combines an accessible Flutter app, a Twilio-based phone-call backend, Supabase data storage, and AI-powered conversation/letter understanding so a user can check in with Cura by tapping an orb in the app or by receiving a scheduled phone call.

The project is built around a simple idea: support someone who may be isolated, under pressure, or not comfortable with complex interfaces by making the product feel like a calm conversation rather than a traditional app.

## Naming

- `CarerCarer` = the project / repository / app product name
- `Cura` = the assistant character users talk to inside the app

## What the project does

- Voice check-ins inside the mobile app
- Scheduled outbound check-in calls via Twilio
- AI-generated conversational responses tuned for short, simple UK English
- Post-session extraction of structured wellbeing data
- Letter explanation flow for official documents
- Emergency escalation flow with manual and keyword-triggered paths
- History, transcript review, and profile/schedule management
- Light and dark mode UI across the app

## Core user flows

### 1. In-app voice check-in

1. The user lands on the home screen and taps the central orb.
2. Cura starts an in-app session and opens the active call/check-in screen.
3. The app records audio, sends it through the AI/audio pipeline, and returns a short spoken response.
4. After the conversation, the session is saved and can be reviewed in History.

### 2. Scheduled phone call

1. The user sets morning, afternoon, and evening call times in the schedule screen.
2. The app or background trigger requests an outbound call from the Node/Twilio backend.
3. Twilio calls the user, plays Cura’s greeting, gathers speech, and loops through the voice conversation.
4. If the call completes, the backend and app state are updated and the conversation can be persisted.

### 3. Letter explanation

1. The user opens “Explain a letter”.
2. They attach a photo and/or paste the document text.
3. Cura sends the content to the AI layer and returns:
   - document type
   - what it means
   - what the user needs to do
   - what happens if they do nothing

### 4. Emergency escalation

Emergency can be triggered either manually from the app or from detected crisis language in a conversation. The product is designed to escalate rather than diagnose.

## Repository layout

```text
App_Tests/
├── README.md                  # GitHub landing page for the whole repo
├── render.yaml                # Render blueprint for the backend deployment
└── cura/
    ├── lib/                   # Flutter app source
    ├── backend/               # Node + Express + Twilio backend
    ├── supabase/              # Database migrations
    ├── android/               # Android project
    ├── ios/                   # iOS project
    ├── test/                  # Flutter widget tests
    └── pubspec.yaml           # Flutter dependencies and assets
```

## Architecture

### App layer

The Flutter app is responsible for:

- navigation and screen composition
- recording and playback
- session state management
- profile, history, schedule, and letter flows
- emergency UI and escalation entry points

Primary app building blocks:

- `flutter_riverpod` for dependency injection and state
- `go_router` for routing
- `supabase_flutter` for auth and persistence
- `record`, `just_audio`, `audio_session` for audio
- `device_calendar` for appointment/calendar integration
- `image_picker` for the letter flow

Important app files:

- `cura/lib/main.dart`
- `cura/lib/core/routing/app_router.dart`
- `cura/lib/core/di/providers.dart`
- `cura/lib/features/home/screens/home_screen.dart`
- `cura/lib/features/conversation/providers/conversation_provider.dart`
- `cura/lib/services/claude_service.dart`
- `cura/lib/services/fish_audio_service.dart`
- `cura/lib/services/supabase_service.dart`
- `cura/lib/services/emergency_service.dart`

### Backend layer

The backend exists because Supabase alone cannot securely:

- hold Twilio secrets
- initiate outbound calls
- return TwiML
- receive call status callbacks

The backend currently provides:

- `GET /health`
- `POST /initiate-call`
- `POST /emergency-call`
- `POST /twiml`
- `POST /respond`
- `POST /call-status`

Important backend files:

- `cura/backend/server.js`
- `cura/backend/package.json`
- `render.yaml`

### Data layer

Supabase stores user and session data. The checked-in migration defines:

- `user_profiles`
- `emergency_contacts`
- `linked_family_members`
- `check_in_sessions`
- `medications`
- `appointments`
- `emergency_events`
- `weekly_analyses`
- `letter_explanations`

Migration file:

- `cura/supabase/migrations/001_initial_schema.sql`

## AI and conversation model

Despite the historical filename `claude_service.dart`, the current app-side chat/extraction integration uses OpenAI endpoints and OpenAI keys.

Current AI responsibilities include:

- generating brief conversational check-in replies
- structured extraction from transcripts
- letter explanation into plain English
- calendar tool usage from the chat layer

The backend also uses OpenAI for phone-call replies.

## Design system and UI direction

The UI is intentionally not a default Material app. The current direction is:

- frosted/glass surfaces
- soft ambient backgrounds
- large, calm primary interaction targets
- minimal cognitive load
- theme-aware light and dark mode styling

Recent work also moved the other screens onto the same visual language as the home screen and corrected the bottom tab bar so it renders flush to the bottom of the screen.

## Tech stack

### Mobile app

- Flutter
- Dart
- Riverpod
- GoRouter
- Supabase
- OpenAI
- Fish Audio
- Twilio integration through backend
- Firebase Messaging / local notifications
- Workmanager

### Backend

- Node.js
- Express
- Twilio
- OpenAI
- Axios / FormData
- dotenv

### Infrastructure

- Supabase
- Render
- GitHub

## Local development

### Prerequisites

- Flutter SDK
- Xcode for iOS development
- Android Studio / Android SDK for Android development
- Node.js 20+ for the backend
- A Supabase project
- Twilio credentials
- OpenAI API key
- Fish Audio API key if you want the full voice flow

### 1. Clone the repo

```bash
git clone https://github.com/Erdem093/CarerCarer.git
cd CarerCarer
```

### 2. App environment

Create `cura/.env` with the app-side variables:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
FISH_AUDIO_API_KEY=your-fish-audio-key
OPENAI_API_KEY=your-openai-key
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your-auth-token
TWILIO_PHONE_NUMBER=+14155552671
BACKEND_URL=http://localhost:3000
```

Important note:

- Some older placeholder files still mention `CLAUDE_API_KEY`.
- The current app and backend code use `OPENAI_API_KEY`.
- If you are configuring the project from scratch, use `OPENAI_API_KEY`.

### 3. Backend environment

Create `cura/backend/.env` with:

```env
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+14155552671
FISH_AUDIO_API_KEY=your_fish_audio_key
OPENAI_API_KEY=your_openai_key
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your_service_role_key
PORT=3000
PUBLIC_URL=http://localhost:3000
```

### 4. Run the backend

```bash
cd cura/backend
npm ci
npm run dev
```

### 5. Run the Flutter app

```bash
cd cura
flutter pub get
flutter run
```

### 6. Apply Supabase schema

Use the migration in:

```text
cura/supabase/migrations/001_initial_schema.sql
```

You can apply it through the Supabase CLI or the Supabase SQL editor.

## Deployment

The repo already includes a Render blueprint:

- `render.yaml`

That blueprint deploys the backend from:

- `cura/backend`

### Render flow

1. Push the repo to GitHub.
2. In Render, create a new Blueprint deployment.
3. Select this repository.
4. Approve the checked-in `render.yaml`.
5. Fill in the required environment variables.
6. Deploy.

### Backend environment variables for Render

- `PUBLIC_URL`
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_PHONE_NUMBER`
- `FISH_AUDIO_API_KEY`
- `OPENAI_API_KEY`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_KEY`

### After deployment

Set the app-side `BACKEND_URL` to the deployed backend URL, for example:

```env
BACKEND_URL=https://your-render-service.onrender.com
```

## Testing

The repo includes Flutter widget tests under:

- `cura/test/`

The tests focus on UI structure and regression coverage. In the current environment used to edit this repo, `flutter`/`dart` were not available on `PATH`, so verification from here was limited to code inspection rather than executing the test suite.

Run tests locally with:

```bash
cd cura
flutter test
```

## Current project status

The codebase already supports:

- in-app voice check-ins
- scheduled and manual phone-call flows
- transcript extraction
- history review
- emergency contacts and escalation entry points
- profile and schedule management
- letter explanation
- a design system covering light and dark mode

Areas that are still prototype-grade or worth tightening:

- some legacy filenames still use older naming (`ClaudeService`) even though the code now targets OpenAI
- placeholder docs and env examples in subfolders may lag behind runtime reality
- mobile setup still depends on correct native permissions and API credentials
- phone-call flows depend on a reachable public backend URL for Twilio callbacks

## Safety note

Cura is positioned as a supportive companion, not a diagnostic or treatment system. The app and backend prompts intentionally steer the product toward escalation and emergency guidance rather than medical advice.

## License

No license file is currently checked into the repository. If this is intended to be public or reused, add an explicit license before treating the project as open source.
