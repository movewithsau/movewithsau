-- =====================================================================
-- MOVE · Entry / VIP · SQL base (borrador del 23 nov 2026)
-- 100 % aditivo e idempotente: se puede correr más de una vez sin romper nada.
-- No borra ni modifica datos. Solo agrega columnas, tablas, índices y una vista.
-- Correr en Supabase > SQL Editor, DESPUÉS de hacer el backup (paso 0).
-- =====================================================================

-- 0) BACKUP de la única tabla existente que se toca (solo se le agregan columnas)
create table if not exists public.clients_backup_20261123 as
  select * from public.clients;

-- 1) COLUMNAS NUEVAS EN clients (todas con default: ningún cliente actual cambia)
alter table public.clients add column if not exists tier text not null default 'vip';
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'clients_tier_check') then
    alter table public.clients add constraint clients_tier_check check (tier in ('entry','vip'));
  end if;
end $$;

alter table public.clients add column if not exists payment_due_date date;
alter table public.clients add column if not exists vip_offer_active boolean not null default false;
alter table public.clients add column if not exists vip_offer_dismissed_at timestamptz;
alter table public.clients add column if not exists onboarding_required boolean not null default false;
alter table public.clients add column if not exists nopain_accepted_at timestamptz;

-- 2) TABLAS NUEVAS (el tipo de client_id se copia automáticamente del tipo real de clients.id)
do $do$
declare
  t text;
begin
  select format_type(a.atttypid, a.atttypmod) into t
  from pg_attribute a
  where a.attrelid = 'public.clients'::regclass and a.attname = 'id' and not a.attisdropped;

  if t is null then
    raise exception 'No encontré clients.id: avisale a Claude antes de seguir';
  end if;

  execute format($f$
    create table if not exists public.client_onboarding (
      id bigint generated always as identity primary key,
      client_id %s not null unique references public.clients(id),
      profession text,
      email text,
      goal text,
      success_text text,
      injuries text,
      equipment text,
      days_per_week int,
      experience int check (experience between 1 and 10),
      extra text,
      terms_accepted_at timestamptz,
      tour_seen_at timestamptz,
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    )$f$, t);

  execute format($f$
    create table if not exists public.support_messages (
      id bigint generated always as identity primary key,
      client_id %s not null references public.clients(id),
      sender text not null check (sender in ('client','coach')),
      kind text not null default 'text' check (kind in ('text','photo','audio','request_run','request_vip')),
      body text,
      media_path text,
      tag text not null default 'support' check (tag in ('support','vip','run')),
      starred boolean not null default false,
      status text not null default 'new' check (status in ('new','answered')),
      created_at timestamptz not null default now(),
      read_at timestamptz
    )$f$, t);

  execute format($f$
    create table if not exists public.entry_lift_habits (
      id bigint generated always as identity primary key,
      client_id %s not null references public.clients(id),
      habit text not null,
      started_on date not null default current_date,
      active boolean not null default true,
      created_at timestamptz not null default now()
    )$f$, t);

  execute format($f$
    create table if not exists public.entry_lift_checkins (
      id bigint generated always as identity primary key,
      client_id %s not null references public.clients(id),
      habit_id bigint not null references public.entry_lift_habits(id),
      check_date date not null,
      created_at timestamptz not null default now(),
      unique (habit_id, check_date)
    )$f$, t);

  execute format($f$
    create table if not exists public.entry_lift_raffles (
      id bigint generated always as identity primary key,
      month_start date not null unique,
      winner_client_id %s references public.clients(id),
      drawn_at timestamptz,
      created_at timestamptz not null default now()
    )$f$, t);

  execute format($f$
    create table if not exists public.client_rate_us (
      id bigint generated always as identity primary key,
      client_id %s not null unique references public.clients(id),
      stars int not null check (stars between 1 and 5),
      comment text,
      created_at timestamptz not null default now()
    )$f$, t);
end
$do$;

-- 3) ÍNDICES
create index if not exists idx_support_messages_client_created on public.support_messages (client_id, created_at);
create index if not exists idx_support_messages_starred_created on public.support_messages (starred, created_at);
create index if not exists idx_entry_lift_checkins_client_date on public.entry_lift_checkins (client_id, check_date);
create index if not exists idx_entry_lift_habits_client on public.entry_lift_habits (client_id);

-- 4) VISTA DE SOLO LECTURA: qué mensajes tocaría el borrado de 7 días (no borra nada)
create or replace view public.support_messages_purgeable as
select m.id, m.client_id, m.media_path, m.created_at
from public.support_messages m
where m.starred = false
  and m.created_at < now() - interval '7 days'
  and not (
    m.sender = 'client'
    and not exists (
      select 1 from public.support_messages r
      where r.client_id = m.client_id and r.sender = 'coach' and r.created_at > m.created_at
    )
  );

-- 5) BUCKET PRIVADO para fotos y audios del chat
insert into storage.buckets (id, name, public)
values ('support-chat', 'support-chat', false)
on conflict (id) do nothing;
