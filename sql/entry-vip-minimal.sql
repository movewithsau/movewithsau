-- =====================================================================
-- MOVE · E10 · Marca de "Entreno para poco tiempo" (24 nov 2026)
-- 100 % aditivo e idempotente: agrega una columna con default false.
-- Todas las filas existentes quedan en false; no se cambia ningún otro dato.
-- =====================================================================

alter table public.workout_sessions
  add column if not exists is_minimal boolean not null default false;

-- Verificación (solo lectura): debería salir 1 fila, boolean, default false.
select column_name, data_type, column_default
  from information_schema.columns
 where table_schema = 'public' and table_name = 'workout_sessions' and column_name = 'is_minimal';
