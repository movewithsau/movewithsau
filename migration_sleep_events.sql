-- =====================================================================
-- MOVE · Mi diario · Sueño como eventos (dormir / despertar)
-- Rama: feat/notes-plates-assist
--
-- SOLO ADITIVO: tabla nueva. diary_sleep NO se toca: sus filas viejas quedan
-- intactas, no se migran y se siguen leyendo junto con los eventos.
-- clients.id es uuid (verificado), así que client_id es uuid con FK.
-- RLS sigue deshabilitado: no se agregan policies.
-- event_at se guarda en UTC; la app asigna la noche con hora de Costa Rica (UTC-6).
-- Correr en el SQL Editor de Supabase.
-- =====================================================================

create extension if not exists pgcrypto;

create table if not exists diary_sleep_events (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references clients(id),
  kind        text not null check (kind in ('sleep','wake')),
  event_at    timestamptz not null,
  created_at  timestamptz not null default now(),
  deleted_at  timestamptz null
);

create index if not exists diary_sleep_events_client_event_idx
  on diary_sleep_events (client_id, event_at);

-- Verificación (solo lectura)
select column_name, data_type, is_nullable
from information_schema.columns
where table_name = 'diary_sleep_events'
order by ordinal_position;

-- ---------------------------------------------------------------------
-- ROLLBACK (NO correr salvo que Sau lo pida): borra SOLO esta tabla nueva.
-- diary_sleep y el resto de las tablas no se tocan.
-- ---------------------------------------------------------------------
-- drop table if exists diary_sleep_events;
