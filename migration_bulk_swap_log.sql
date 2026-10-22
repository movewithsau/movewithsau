-- =====================================================================
-- MOVE · Reemplazo masivo de ejercicios · respaldo para deshacer
-- Rama: feat/bulk-replace
--
-- SOLO ADITIVO: tabla nueva. No toca exercises, exercise_logs ni ninguna otra.
-- clients.id es uuid (verificado), así que client_id es uuid con FK.
-- RLS sigue deshabilitado: no se agregan policies.
-- Correr en el SQL Editor de Supabase.
--
-- before_data: [{id, name, muscle_group, video_url, tag}] por cada ejercicio, antes del cambio.
-- after_data:  {name, muscle_group, video_url, tag, applied_ids:[...], failed_ids:[...]}
-- Deshacer restaura before_data solo en los ids que siguen con el valor de after_data
-- y marca reverted_at. Nada se borra.
-- =====================================================================

create extension if not exists pgcrypto;

create table if not exists program_bulk_edits (
  id           uuid primary key default gen_random_uuid(),
  client_id    uuid not null references clients(id),
  created_at   timestamptz not null default now(),
  description  text,
  before_data  jsonb not null,
  after_data   jsonb not null,
  reverted_at  timestamptz null
);

create index if not exists program_bulk_edits_client_created_idx
  on program_bulk_edits (client_id, created_at desc);

-- Verificación (solo lectura)
select column_name, data_type, is_nullable
from information_schema.columns
where table_name = 'program_bulk_edits'
order by ordinal_position;
