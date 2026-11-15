-- ============================================================================
-- MOVE · Módulo Run v1 · 14 nov 2026
-- Aditivo: una columna nueva en clients y ocho tablas nuevas (prefijo run_).
-- No borra ni modifica ningún dato existente. Correr en el SQL Editor de Supabase.
--
-- Tipos verificados en el código:
--   clients.id   uuid  (ver migration_workout_checkin.sql)
-- El módulo solo LEE exercise_logs, exercises, monthly_plans, workout_completions
-- y exercise_library: nunca escribe en ellas.
--
-- pendiente: endurecer RLS, contiene datos de salud.
-- RLS desactivado en el proyecto (igual que el resto del app): no se agregan policies.
-- ============================================================================

-- 0) Verificación ANTES (anotá los números)
select count(*) as clientes from clients;
select to_regclass('public.run_profiles')         as run_profiles_existe,          -- debe dar NULL
       to_regclass('public.run_planned_sessions') as run_planned_sessions_existe,  -- NULL
       to_regclass('public.run_sessions')         as run_sessions_existe,          -- NULL
       to_regclass('public.run_shoes')            as run_shoes_existe,             -- NULL
       to_regclass('public.run_checkins')         as run_checkins_existe,          -- NULL
       to_regclass('public.run_alerts')           as run_alerts_existe,            -- NULL
       to_regclass('public.run_exercises')        as run_exercises_existe,         -- NULL
       to_regclass('public.run_routines')         as run_routines_existe;          -- NULL

-- 1) Interruptor por cliente (apagado por defecto). Única modificación a una tabla existente.
alter table clients
  add column if not exists run_module_enabled boolean not null default false;

-- 2) Perfil Run: uno por cliente
create table if not exists run_profiles (
  id                   uuid primary key default gen_random_uuid(),
  client_id            uuid not null unique references clients(id) on delete cascade,
  mode                 text not null default 'plan' check (mode in ('plan','seguimiento')),
  level                int  null check (level between 1 and 3),
  plan_status          text not null default 'none' check (plan_status in ('none','draft','active','paused')),
  start_date           date null,
  weeks_total          int  null check (weeks_total between 1 and 52),
  paused_at            timestamptz null,
  resume_reduced_week  int  null,               -- semana con tope en versión reducida tras reanudar
  goal                 text null,
  onboarding_answers   jsonb not null default '{}'::jsonb,
  alerts               jsonb not null default '[]'::jsonb, -- resumen de alertas del onboarding
  coach_notes          text null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- 3) Sesiones planeadas (sin día asignado: el cliente elige qué y cuándo)
create table if not exists run_planned_sessions (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid not null references clients(id) on delete cascade,
  week_number      int  not null check (week_number >= 1),
  week_type        text not null default 'normal' check (week_type in ('normal','descarga','prueba_5k')),
  position         int  not null default 0,
  session_type     text not null check (session_type in ('correr_caminar','facil','larga_facil','strides','umbral','prueba_5k')),
  minutes          int  not null check (minutes between 5 and 180),
  distance_km      numeric(6,2) null,
  effort           text null,                   -- ej. "3-4"
  notes            text null,
  pre_routine_id   uuid null,                   -- run_routines.id (sin FK: un bloque borrado no traba la sesión)
  post_routine_id  uuid null,
  overrides        jsonb not null default '{}'::jsonb, -- {"reducida":{...},"minima":{...}} solo lo sobrescrito
  status           text not null default 'planeada' check (status in ('planeada','hecha','omitida')),
  run_session_id   uuid null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists run_planned_sessions_client_week_idx on run_planned_sessions (client_id, week_number, position);

-- 4) Zapatos (los km totales se calculan: initial_km + suma de run_sessions.distance_km)
create table if not exists run_shoes (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references clients(id) on delete cascade,
  name        text not null,
  brand       text null,
  initial_km  numeric(7,2) not null default 0,
  start_date  date null,
  retired_at  timestamptz null,
  created_at  timestamptz not null default now()
);
create index if not exists run_shoes_client_idx on run_shoes (client_id);

-- 5) Corridas registradas (manual)
create table if not exists run_sessions (
  id                  uuid primary key default gen_random_uuid(),
  client_id           uuid not null references clients(id) on delete cascade,
  kind                text not null check (kind in ('plan','libre')),
  planned_session_id  uuid null,
  version_used        text null check (version_used in ('completa','reducida','minima')),
  session_date        date not null,
  session_type        text null,               -- plan: el de la sesión; libre: facil|larga|intervalos|otra
  distance_km         numeric(6,2) null,
  duration_min        numeric(6,1) null,
  effort              int  null check (effort between 1 and 10),
  avg_hr              int  null,
  elevation           int  null,
  terrain             text null,
  shoe_id             uuid null,
  notes               text null,
  leg_after           text null,               -- 'esperar' | 'igual' | null (respuesta a "¿pierna hoy?")
  source              text not null default 'manual',
  created_at          timestamptz not null default now()
);
create index if not exists run_sessions_client_date_idx on run_sessions (client_id, session_date desc);
create index if not exists run_sessions_shoe_idx on run_sessions (shoe_id);

-- 6) Check-in diario (uno por cliente y día; upsert)
create table if not exists run_checkins (
  id              uuid primary key default gen_random_uuid(),
  client_id       uuid not null references clients(id) on delete cascade,
  checkin_date    date not null,
  energy          int  null check (energy between 1 and 5),
  sleep           text null check (sleep in ('mal','regular','bien')),
  pain            text null check (pain in ('ninguno','leve','moderado','fuerte')),
  pain_zone       text null,
  stress          int  null check (stress between 1 and 5),
  alarm_symptom   boolean not null default false,
  leg_recent      boolean null,                 -- solo si el app no pudo deducirlo
  recommendation  jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (client_id, checkin_date)
);
create index if not exists run_checkins_client_date_idx on run_checkins (client_id, checkin_date desc);

-- 7) Alertas al coach (nunca delete: resolver = update)
create table if not exists run_alerts (
  id           uuid primary key default gen_random_uuid(),
  client_id    uuid not null references clients(id) on delete cascade,
  type         text not null check (type in ('alarma','dolor_3_dias','dolor_fuerte','onboarding_roja','onboarding_amarilla','sin_registro')),
  detail       text null,
  status       text not null default 'open' check (status in ('open','resolved')),
  created_at   timestamptz not null default now(),
  resolved_at  timestamptz null
);
create index if not exists run_alerts_client_status_idx on run_alerts (client_id, status, created_at desc);

-- 8) Ejercicios de Run (no se toca exercise_library)
create table if not exists run_exercises (
  id                 uuid primary key default gen_random_uuid(),
  coach_id           uuid null,
  category           text not null check (category in ('pre','post','apoyo')),
  name               text not null,
  description        text null,
  cues               text null,               -- indicaciones
  video_url          text null,
  dose               text null,               -- duración o repeticiones, ej. "30 s" o "2 x 10"
  levels             int[] not null default '{1,2,3}',
  contraindications  text null,
  is_example         boolean not null default false,
  created_at         timestamptz not null default now()
);

-- 9) Bloques pre/post por tipo de sesión
create table if not exists run_routines (
  id            uuid primary key default gen_random_uuid(),
  coach_id      uuid null,
  session_type  text not null,
  block         text not null check (block in ('pre','post')),
  name          text not null,
  exercise_ids  jsonb not null default '[]'::jsonb, -- en orden
  is_default    boolean not null default true,
  created_at    timestamptz not null default now()
);
create index if not exists run_routines_type_idx on run_routines (session_type, block);

-- 10) Unos pocos ejemplos marcados "ejemplo" (Sau escribe el contenido real después)
insert into run_exercises (category, name, description, dose, levels, is_example)
select * from (values
  ('pre',   'Ejemplo · Balanceo de pierna',   'Movilidad dinámica de cadera antes de correr.', '10 por lado', '{1,2,3}'::int[], true),
  ('pre',   'Ejemplo · Skipping suave',        'Activación de bajo impacto.',                   '2 x 20 s',    '{1,2,3}'::int[], true),
  ('post',  'Ejemplo · Caminata de vuelta',    'Bajar pulsaciones caminando (práctica de coaching).', '5 min', '{1,2,3}'::int[], true),
  ('apoyo', 'Ejemplo · Elevación de talones',  'Fuerza de pantorrilla. Opcional y de bajo impacto en niveles 1 y 2.', '3 x 12', '{1,2,3}'::int[], true)
) as v(category, name, description, dose, levels, is_example)
where not exists (select 1 from run_exercises where is_example);

-- 11) Verificación DESPUÉS
select count(*) as clientes_despues from clients;                 -- igual que antes
select count(*) filter (where run_module_enabled) as con_run from clients; -- 0
select count(*) as run_exercises_ejemplo from run_exercises;      -- 4

-- ============================================================================
-- ROLLBACK (solo lo nuevo; descomentá si hiciera falta)
-- drop table if exists run_routines;
-- drop table if exists run_exercises;
-- drop table if exists run_alerts;
-- drop table if exists run_checkins;
-- drop table if exists run_sessions;
-- drop table if exists run_shoes;
-- drop table if exists run_planned_sessions;
-- drop table if exists run_profiles;
-- alter table clients drop column if exists run_module_enabled;
-- ============================================================================
