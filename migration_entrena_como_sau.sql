-- ============================================================================
-- MOVE · Entrena como Sau, bienvenida y sesión con cronómetro · 16 nov 2026
-- Rama: feat/entrena-como-sau
--
-- ADITIVO: crea 3 tablas nuevas. NO modifica ninguna tabla existente
-- (sin ALTER, sin UPDATE, sin DELETE sobre lo que ya existe).
-- Correr en el SQL Editor de Supabase, en orden.
--
-- Tipos verificados en el código:
--   clients.id        uuid  (ver migration_run_module.sql, migration_rating_10.sql)
--   diary_entries.id  uuid  (el app lo crea con crypto.randomUUID())
--
-- pendiente: endurecer RLS.
-- RLS desactivado en el proyecto (igual que el resto del app): no se agregan policies.
-- Como no hay RLS, el app filtra toda consulta del cliente por su client_id.
-- ============================================================================

-- 0) Verificación ANTES (anotá los números)
select count(*) as clientes      from clients;
select count(*) as diario_filas  from diary_entries;
select to_regclass('public.coach_daily_posts')   as coach_daily_posts_existe,   -- debe dar NULL
       to_regclass('public.client_welcome_seen') as client_welcome_seen_existe, -- NULL
       to_regclass('public.sau_sessions')        as sau_sessions_existe;        -- NULL

-- 1) Publicación "Entrena como Sau" (una activa a la vez).
--    Activa = replaced_at is null and expires_at > now().
--    Al publicar otra, la anterior recibe replaced_at (nunca se borra).
create table if not exists coach_daily_posts (
  id            uuid primary key default gen_random_uuid(),
  body          text not null check (char_length(body) between 1 and 500),
  published_at  timestamptz not null default now(),
  expires_at    timestamptz not null,               -- published_at + 24 h (lo pone el app)
  push_sent     boolean not null default false,
  replaced_at   timestamptz null,
  created_at    timestamptz not null default now(),
  check (expires_at > published_at)
);
create index if not exists coach_daily_posts_published_idx
  on coach_daily_posts (published_at desc);

-- 2) Bienvenida de la abeja: una fila por cliente y día (fecha de Costa Rica).
create table if not exists client_welcome_seen (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references clients(id) on delete cascade, -- el app borra clientes: que esta tabla no lo trabe
  seen_date   date not null,                          -- fecha America/Costa_Rica
  created_at  timestamptz not null default now(),
  unique (client_id, seen_date)
);

-- 3) Sesiones "Entrenar como Sau" (cronómetro + notas del cliente).
--    No cuentan como entreno del plan: no tocan days_trained, hitos, rachas ni Hive.
create table if not exists sau_sessions (
  id                         uuid primary key default gen_random_uuid(),
  client_id                  uuid not null references clients(id) on delete cascade,
  post_id                    uuid null references coach_daily_posts(id) on delete set null,
  post_body_snapshot         text null,              -- copia del texto al empezar
  started_at                 timestamptz not null,
  paused_at                  timestamptz null,
  paused_total_seconds       int not null default 0 check (paused_total_seconds >= 0),
  ended_at                   timestamptz null,
  status                     text not null default 'running'
                               check (status in ('running','paused','finished','auto_stopped')),
  duration_seconds           int null check (duration_seconds is null or duration_seconds >= 0),
  original_duration_seconds  int null,               -- solo se llena la primera vez que Sau ajusta
  adjusted_by_coach          boolean not null default false,
  adjusted_at                timestamptz null,
  notes                      text null,
  notes_updated_at           timestamptz null,
  diary_entry_id             uuid null references diary_entries(id) on delete set null,
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz not null default now()
);
create index if not exists sau_sessions_client_started_idx
  on sau_sessions (client_id, started_at desc);
create index if not exists sau_sessions_client_status_idx
  on sau_sessions (client_id, status);
-- Una sola sesión activa por cliente (evita duplicados por doble toque o dos dispositivos)
create unique index if not exists sau_sessions_one_active_idx
  on sau_sessions (client_id) where status in ('running','paused');

-- 4) Verificación DESPUÉS
select count(*) as clientes_despues     from clients;        -- igual que antes
select count(*) as diario_filas_despues from diary_entries;  -- igual que antes
select (select count(*) from coach_daily_posts)   as posts,     -- 0
       (select count(*) from client_welcome_seen) as welcome,   -- 0
       (select count(*) from sau_sessions)        as sesiones;  -- 0

-- ============================================================================
-- ROLLBACK (solo lo nuevo; descomentá si hiciera falta)
-- drop table if exists sau_sessions;
-- drop table if exists client_welcome_seen;
-- drop table if exists coach_daily_posts;
-- ============================================================================
