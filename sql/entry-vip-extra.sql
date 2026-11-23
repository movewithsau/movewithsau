-- =====================================================================
-- MOVE · Entry / VIP · SQL extra (23 nov 2026)
-- Va DESPUÉS de sql/entry-vip-base.sql. Solo agrega lo que la Fase 0 encontró que falta.
-- Aditivo e idempotente: se puede correr más de una vez. No borra ni cambia datos de clientes.
-- Lo corre Sau en Supabase > SQL Editor, con backup antes (ver sql/README-entry-vip.md).
-- =====================================================================

-- 1) client_onboarding: dos marcas que el SQL base no tiene
--    completed_at: el cliente terminó SU onboarding (Entry o VIP). Hace falta aparte de que
--      exista la fila porque en VIP Sau puede crear la fila desde la ficha antes de que el
--      cliente entre; sin esta marca el app no sabría si el cliente ya lo vio.
--    rate_us_dismissed_at: el cliente tocó "Ahora no" en el Rate us del día 20, para no
--      volver a mostrarlo (client_rate_us exige estrellas, así que no sirve para esto).
alter table public.client_onboarding add column if not exists completed_at timestamptz;
alter table public.client_onboarding add column if not exists rate_us_dismissed_at timestamptz;

-- 2) Bucket support-chat: límite de 15 MB por archivo (fotos y audios del chat).
--    Toca solo la fila del bucket nuevo creado por el SQL base; ningún otro bucket.
update storage.buckets
   set file_size_limit = 15728640
 where id = 'support-chat'
   and (file_size_limit is distinct from 15728640);

-- 3) Policy de Storage SOLO para support-chat, mismo patrón que progress_photos_all_access
--    (ALL, rol public, filtrada por bucket_id). Es el único lugar con policies: las tablas
--    siguen sin RLS ni policies.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname = 'support_chat_all_access'
  ) then
    create policy support_chat_all_access on storage.objects
      for all to public
      using (bucket_id = 'support-chat')
      with check (bucket_id = 'support-chat');
  end if;
end $$;

-- 4) Verificación (solo lectura): debería mostrar 2 columnas, el bucket con 15728640 y la policy.
select column_name, data_type from information_schema.columns
 where table_schema = 'public' and table_name = 'client_onboarding'
   and column_name in ('completed_at', 'rate_us_dismissed_at');
select id, public, file_size_limit from storage.buckets where id = 'support-chat';
select policyname, cmd, roles from pg_policies
 where schemaname = 'storage' and tablename = 'objects' and policyname = 'support_chat_all_access';
