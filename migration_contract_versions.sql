-- ============================================================================
-- MOVE · Machote de contrato v2 con versionado · 27 oct 2026
-- Aditivo: tres columnas nuevas en contracts, todas nullable. No borra ni
-- modifica ningún contrato existente (firmado o pendiente): quedan sin versión,
-- sin snapshot y sin semanas, y el app los sigue mostrando con el texto v1.
-- Correr en el SQL Editor de Supabase ANTES de crear contratos nuevos.
--
--   contract_version        int   null  -> 2 en contratos nuevos; null = v1 (los de antes)
--   contract_text_snapshot  text  null  -> copia exacta del texto aceptado, se guarda al firmar
--   duration_weeks          int   null  -> semanas pactadas (las usa el texto v2)
-- RLS desactivado en el proyecto: no se agregan policies.
-- ============================================================================

-- 0) Verificación ANTES (anotá los números)
select count(*) as total,
       count(*) filter (where status = 'firmado')  as firmados,
       count(*) filter (where status <> 'firmado' or status is null) as pendientes
  from contracts;

-- Pendientes que ya existen (quedan en v1 hasta que Sau diga otra cosa)
select c.id, cl.name, c.program, c.duration, c.total_amount, c.created_at
  from contracts c join clients cl on cl.id = c.client_id
 where c.status <> 'firmado' or c.status is null
 order by c.created_at;

-- 1) Columnas nuevas
alter table contracts add column if not exists contract_version int null;
alter table contracts add column if not exists contract_text_snapshot text null;
alter table contracts add column if not exists duration_weeks int null;

-- 2) Verificación DESPUÉS: mismos totales y nada con versión todavía
select count(*) as total,
       count(*) filter (where status = 'firmado')  as firmados,
       count(*) filter (where status <> 'firmado' or status is null) as pendientes,
       count(contract_version)       as con_version,   -- 0
       count(contract_text_snapshot) as con_snapshot,  -- 0
       count(duration_weeks)         as con_semanas    -- 0
  from contracts;

-- ----------------------------------------------------------------------------
-- ROLLBACK (solo borra lo nuevo; descomentá si hace falta)
-- Ojo: si ya se firmaron contratos v2, borrar contract_text_snapshot pierde la
-- copia del texto aceptado. Respaldá antes:
--   create table contracts_snapshot_backup as
--     select id, contract_version, contract_text_snapshot, duration_weeks from contracts
--      where contract_version is not null;
-- alter table contracts drop column if exists duration_weeks;
-- alter table contracts drop column if exists contract_text_snapshot;
-- alter table contracts drop column if exists contract_version;
-- ----------------------------------------------------------------------------
