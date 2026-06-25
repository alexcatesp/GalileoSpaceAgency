-- ===========================================================================
-- GASA — Estado del juego (Supabase / Postgres)
-- Migración 0001 — esquema inicial + RLS + auth seudónima
-- Referencia de diseño: PRD §4 (privacidad), §5.2 (modelo de datos), §9.2.
--
-- Principio rector: seudonimización en la puerta. El backend NUNCA ve un nombre
-- real. La identidad es `candidato_id` (GASA-2627-NNN), que viaja como claim
-- `app_metadata.candidato_id` en el JWT del usuario de Supabase Auth. El email
-- de Auth es SINTÉTICO y no enrutable (no es PII, no se muestra nunca).
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Helper: candidato_id del usuario autenticado (leído del JWT, no falsificable
-- por el cliente — lo fija el profesor en la provisión vía service_role).
-- ---------------------------------------------------------------------------
create or replace function public.gasa_candidato_id()
returns text
language sql
stable
as $$
  select nullif(auth.jwt() -> 'app_metadata' ->> 'candidato_id', '')::text;
$$;

comment on function public.gasa_candidato_id() is
  'candidato_id del usuario autenticado, tomado del claim app_metadata.candidato_id del JWT. Fijado en la provisión por el profesor; el alumno no puede alterarlo.';

-- ---------------------------------------------------------------------------
-- candidato — perfil seudónimo (PRD §5.2). Una fila por tripulante.
-- Se crea en el Día 1 al completar la ficha de ingreso (alta).
-- ---------------------------------------------------------------------------
create table if not exists public.candidato (
  candidato_id  text primary key
                check (candidato_id ~ '^GASA-[0-9]{4}-[0-9]{3}$'),
  auth_user_id  uuid not null unique references auth.users (id) on delete cascade,
  callsign      text not null check (char_length(callsign) between 2 and 24),
  avatar_id     text not null,                 -- referencia a asset de galería (no imagen personal)
  alta_ts       timestamptz not null default now()
);

comment on table public.candidato is
  'Perfil seudónimo del tripulante. Sin PII: callsign (alias) + avatar de galería. PRD §5.2.';

-- ---------------------------------------------------------------------------
-- logro — LOG append-only: el corazón del sistema (PRD §5.2, §5.5).
-- Cada certificación obtenida es una fila NUEVA. No se actualiza ni se borra.
-- xp_total, rango, ranking, credencial y mapa se DERIVAN de esta tabla.
-- ---------------------------------------------------------------------------
create table if not exists public.logro (
  id            bigint generated always as identity primary key,
  candidato_id  text not null references public.candidato (candidato_id) on delete cascade,
  il_id         text not null,                 -- FK lógica al IL del módulo (config en git, no en BD)
  nivel         text not null check (nivel in ('Suficiente', 'Notable', 'Excelente')),
  xp            integer not null check (xp >= 0),
  ts            timestamptz not null default now()
);

comment on table public.logro is
  'LOG append-only de certificaciones (IL logrados). Sin UPDATE/DELETE. PRD §5.2.';

create index if not exists logro_candidato_idx on public.logro (candidato_id);

-- ---------------------------------------------------------------------------
-- diagnostico — PRIVADO del profesor (PRD §4.2, §5.2).
-- NO es XP, NO es ranking. El alumno lo escribe en el ingreso pero NUNCA lo lee.
-- ---------------------------------------------------------------------------
create table if not exists public.diagnostico (
  candidato_id      text primary key references public.candidato (candidato_id) on delete cascade,
  score_transversal numeric,
  score_especifico  numeric,
  ts                timestamptz not null default now()
);

comment on table public.diagnostico is
  'Diagnóstico de ingreso, privado del profesor. NO es XP ni ranking. Sin política SELECT para alumnos. PRD §7.3.';

-- ===========================================================================
-- ROW-LEVEL SECURITY — "cada uno ve lo suyo"; diagnostico solo el profesor.
-- service_role (profesor / scripts admin) bypassa RLS por diseño de Supabase.
-- ===========================================================================
alter table public.candidato   enable row level security;
alter table public.logro       enable row level security;
alter table public.diagnostico enable row level security;

-- Defensa en profundidad a nivel de privilegios: el log es append-only y el
-- diagnóstico no es legible por el alumno, también sin contar con RLS.
revoke update, delete on public.logro       from authenticated;
revoke update, delete on public.logro       from anon;
revoke select, update, delete on public.diagnostico from authenticated;
revoke select, update, delete on public.diagnostico from anon;

-- --- candidato: el alumno ve / crea / edita SOLO su propia fila ------------
create policy candidato_select_propio on public.candidato
  for select to authenticated
  using (auth_user_id = auth.uid());

create policy candidato_insert_propio on public.candidato
  for insert to authenticated
  with check (
    auth_user_id = auth.uid()
    and candidato_id = public.gasa_candidato_id()   -- no puede darse de alta como otro
  );

create policy candidato_update_propio on public.candidato
  for update to authenticated
  using (auth_user_id = auth.uid())
  with check (auth_user_id = auth.uid() and candidato_id = public.gasa_candidato_id());

-- --- logro: el alumno lee e inserta SOLO los suyos (append-only) -----------
create policy logro_select_propio on public.logro
  for select to authenticated
  using (candidato_id = public.gasa_candidato_id());

create policy logro_insert_propio on public.logro
  for insert to authenticated
  with check (candidato_id = public.gasa_candidato_id());
-- (sin políticas UPDATE/DELETE => denegadas: append-only)

-- --- diagnostico: el alumno SOLO inserta el suyo; NUNCA lee ----------------
create policy diagnostico_insert_propio on public.diagnostico
  for insert to authenticated
  with check (candidato_id = public.gasa_candidato_id());
-- (sin política SELECT => el alumno no puede leer; solo service_role/profesor)
