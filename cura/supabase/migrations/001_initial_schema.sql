-- =============================================================
-- Cura — Initial Schema
-- =============================================================

-- User profiles (extends Supabase auth.users)
CREATE TABLE public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT '',
  mobile_number TEXT,              -- E.164 format: +447XXXXXXXXX
  gp_name TEXT,
  gp_surgery TEXT,
  timezone TEXT NOT NULL DEFAULT 'Europe/London',
  morning_call_time TIME NOT NULL DEFAULT '09:00',
  afternoon_call_time TIME NOT NULL DEFAULT '14:00',
  evening_call_time TIME NOT NULL DEFAULT '21:00',
  calls_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  calendar_access_granted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Emergency contacts (up to 3 per user)
CREATE TABLE public.emergency_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone_number TEXT NOT NULL,     -- E.164 format
  priority SMALLINT NOT NULL DEFAULT 1 CHECK (priority BETWEEN 1 AND 3),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Linked family members (receive weekly summaries)
CREATE TABLE public.linked_family_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone_number TEXT,
  email TEXT,
  fcm_token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Check-in sessions (one per voice conversation)
CREATE TABLE public.check_in_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  context TEXT NOT NULL CHECK (context IN ('morning', 'afternoon', 'evening', 'adhoc')),
  mode TEXT NOT NULL CHECK (mode IN ('in_app', 'phone_call')) DEFAULT 'in_app',
  twilio_call_sid TEXT,           -- set for phone_call mode
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  duration_seconds INTEGER,
  transcript JSONB NOT NULL DEFAULT '[]',  -- [{role, content, timestamp}]
  sleep_score SMALLINT CHECK (sleep_score BETWEEN 0 AND 10),
  pain_score SMALLINT CHECK (pain_score BETWEEN 0 AND 10),
  mood_score SMALLINT CHECK (mood_score BETWEEN 0 AND 10),
  pain_location TEXT,
  crisis_flagged BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Medications extracted from voice conversations
CREATE TABLE public.medications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  dosage TEXT,                    -- stored as text, never interpreted medically
  frequency TEXT,
  source_session_id UUID REFERENCES public.check_in_sessions(id),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Appointments extracted from voice conversations
CREATE TABLE public.appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  provider TEXT,
  appointment_date DATE,
  appointment_time TIME,
  location TEXT,
  device_calendar_event_id TEXT,  -- ID in native device calendar
  source_session_id UUID REFERENCES public.check_in_sessions(id),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Emergency escalation events
CREATE TABLE public.emergency_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  trigger_type TEXT NOT NULL CHECK (trigger_type IN ('keyword', 'manual')),
  trigger_text TEXT,
  level_reached SMALLINT NOT NULL CHECK (level_reached BETWEEN 1 AND 3),
  emergency_contact_called BOOLEAN NOT NULL DEFAULT FALSE,
  sms_sent BOOLEAN NOT NULL DEFAULT FALSE,
  call_999_initiated BOOLEAN NOT NULL DEFAULT FALSE,
  session_id UUID REFERENCES public.check_in_sessions(id),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Weekly analysis results
CREATE TABLE public.weekly_analyses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  week_start_date DATE NOT NULL,
  session_count INTEGER NOT NULL DEFAULT 0,
  avg_sleep_score NUMERIC(3,1),
  avg_pain_score NUMERIC(3,1),
  avg_mood_score NUMERIC(3,1),
  analysis_text TEXT NOT NULL,
  flags TEXT[] DEFAULT '{}',
  notification_sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, week_start_date)
);

-- Letter explanations
CREATE TABLE public.letter_explanations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  letter_preview TEXT,            -- first 200 chars of OCR text
  meaning TEXT NOT NULL,
  action_required TEXT NOT NULL,
  consequence TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================
-- Row Level Security
-- =============================================================

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linked_family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.check_in_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.letter_explanations ENABLE ROW LEVEL SECURITY;

-- Policies: users access only their own data
CREATE POLICY "own_data" ON public.user_profiles FOR ALL USING (auth.uid() = id);
CREATE POLICY "own_data" ON public.emergency_contacts FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "own_data" ON public.linked_family_members FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "own_data" ON public.check_in_sessions FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "own_data" ON public.medications FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "own_data" ON public.appointments FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "own_data" ON public.emergency_events FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "own_data" ON public.weekly_analyses FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "own_data" ON public.letter_explanations FOR ALL USING (auth.uid() = user_id);

-- =============================================================
-- Indexes
-- =============================================================

CREATE INDEX idx_sessions_user_date ON public.check_in_sessions(user_id, started_at DESC);
CREATE INDEX idx_medications_user_active ON public.medications(user_id, is_active);
CREATE INDEX idx_appointments_user_date ON public.appointments(user_id, appointment_date ASC);
CREATE INDEX idx_emergency_events_user ON public.emergency_events(user_id, created_at DESC);

-- =============================================================
-- Trigger: auto-create user_profiles row on auth signup
-- =============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
