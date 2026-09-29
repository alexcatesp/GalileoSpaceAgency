-- ===========================================================================
-- GASA — Campus: profesorado, grupos y liberación de capítulos
-- Migración 0002
--
-- Cada profesor libera los capítulos de SUS módulos para SUS grupos desde el
-- panel del profesorado (/gasa/panel/). El juego pregunta qué está abierto para
-- el grupo del alumno con una clave de grupo, sin ver nada más.
--
-- Privacidad: este repositorio es PÚBLICO, así que aquí no hay ningún correo.
-- El administrador da de alta al profesorado desde el panel; el primer
-- administrador se añade una sola vez desde el SQL Editor (ver README).
--
-- Acceso: los profesores entran con un código de un solo uso enviado por correo
-- (OTP de Supabase Auth). Para que su cuenta pueda crearse la primera vez hay
-- que permitir el registro, y por eso un disparador en auth.users rechaza
-- cualquier alta que no sea de un profesor o administrador de la lista, o de un
-- candidato provisionado (con app_metadata.candidato_id).
-- ===========================================================================

create or replace function public.gasa_email()
returns text
language sql
stable
as $$
  select lower(nullif(auth.jwt() ->> 'email', ''));
$$;

comment on function public.gasa_email() is
  'Correo del usuario autenticado, en minúsculas, tomado del JWT.';

-- ---------------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------------
create table if not exists public.campus_admin (
  email text primary key check (email = lower(email) and email like '%_@_%')
);
comment on table public.campus_admin is
  'Administradores del campus: gestionan profesorado, grupos y ajustes. Se añaden desde el SQL Editor.';

create table if not exists public.profesor (
  email   text primary key check (email = lower(email) and email like '%_@_%'),
  nombre  text check (char_length(nombre) <= 80),
  alta_ts timestamptz not null default now()
);
comment on table public.profesor is 'Profesorado con acceso al panel. Lo mantiene el administrador.';

create table if not exists public.grupo (
  id      text primary key check (id ~ '^[A-Z0-9][A-Z0-9-]{1,19}$'),
  nombre  text not null check (char_length(nombre) between 1 and 80),
  clave   text not null unique check (clave ~ '^[A-Z0-9-]{6,24}$'),
  alta_ts timestamptz not null default now()
);
comment on table public.grupo is
  'Grupos de alumnado. La clave es lo que el alumno escribe en el juego; no es un dato personal.';

create table if not exists public.profesor_grupo (
  email  text not null references public.profesor (email) on delete cascade on update cascade,
  modulo text not null check (modulo in ('0485', '0484', '0483', '0373', '0487')),
  grupo  text not null references public.grupo (id) on delete cascade on update cascade,
  primary key (email, modulo, grupo)
);
comment on table public.profesor_grupo is 'Qué módulo imparte cada profesor y en qué grupo.';

create table if not exists public.liberacion (
  modulo   text not null check (modulo in ('0485', '0484', '0483', '0373', '0487')),
  grupo    text not null references public.grupo (id) on delete cascade on update cascade,
  capitulo smallint not null check (capitulo between 0 and 30),
  desde    timestamptz not null default now(),
  por      text not null default public.gasa_email(),
  primary key (modulo, grupo, capitulo)
);
comment on table public.liberacion is
  'Capítulos abiertos por módulo y grupo. Si desde es futuro, el capítulo está programado y se abre solo ese día.';

create table if not exists public.campus_ajuste (
  id             smallint primary key default 1 check (id = 1),
  control_activo boolean not null default false
);
comment on table public.campus_ajuste is
  'Ajustes globales. Mientras control_activo sea false, el juego abre todos los capítulos (despliegue sin sobresaltos).';

insert into public.campus_ajuste (id, control_activo) values (1, false) on conflict (id) do nothing;
-- visitantes sin clave de grupo: el administrador decide qué capítulos ven
insert into public.grupo (id, nombre, clave) values ('PUBLICO', 'Visitantes (sin clave de grupo)', 'PUBLICO-GASA')
  on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Permisos: quién es administrador y quién puede tocar un módulo en un grupo
-- ---------------------------------------------------------------------------
create or replace function public.gasa_es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.campus_admin where email = public.gasa_email());
$$;

create or replace function public.gasa_puede(p_modulo text, p_grupo text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.gasa_es_admin()
      or exists (select 1 from public.profesor_grupo
                 where email = public.gasa_email() and modulo = p_modulo and grupo = p_grupo);
$$;

alter table public.campus_admin   enable row level security;
alter table public.profesor       enable row level security;
alter table public.grupo          enable row level security;
alter table public.profesor_grupo enable row level security;
alter table public.liberacion     enable row level security;
alter table public.campus_ajuste  enable row level security;

-- el alumnado (anon) no lee ninguna tabla: solo usa las funciones públicas de abajo
revoke all on public.campus_admin, public.profesor, public.grupo, public.profesor_grupo,
              public.liberacion, public.campus_ajuste from anon;

create policy campus_admin_select_propio on public.campus_admin
  for select to authenticated using (email = public.gasa_email());

create policy profesor_select on public.profesor
  for select to authenticated using (email = public.gasa_email() or public.gasa_es_admin());
create policy profesor_admin on public.profesor
  for all to authenticated using (public.gasa_es_admin()) with check (public.gasa_es_admin());

create policy grupo_select on public.grupo
  for select to authenticated using (
    public.gasa_es_admin()
    or exists (select 1 from public.profesor_grupo pg where pg.grupo = grupo.id and pg.email = public.gasa_email())
  );
create policy grupo_admin on public.grupo
  for all to authenticated using (public.gasa_es_admin()) with check (public.gasa_es_admin());

create policy profesor_grupo_select on public.profesor_grupo
  for select to authenticated using (email = public.gasa_email() or public.gasa_es_admin());
create policy profesor_grupo_admin on public.profesor_grupo
  for all to authenticated using (public.gasa_es_admin()) with check (public.gasa_es_admin());

create policy liberacion_select on public.liberacion
  for select to authenticated using (public.gasa_puede(modulo, grupo));
create policy liberacion_insert on public.liberacion
  for insert to authenticated with check (public.gasa_puede(modulo, grupo) and por = public.gasa_email());
create policy liberacion_update on public.liberacion
  for update to authenticated using (public.gasa_puede(modulo, grupo))
  with check (public.gasa_puede(modulo, grupo) and por = public.gasa_email());
create policy liberacion_delete on public.liberacion
  for delete to authenticated using (public.gasa_puede(modulo, grupo));

create policy campus_ajuste_select on public.campus_ajuste
  for select to authenticated using (true);
create policy campus_ajuste_admin on public.campus_ajuste
  for update to authenticated using (public.gasa_es_admin()) with check (public.gasa_es_admin());

-- ---------------------------------------------------------------------------
-- Funciones públicas para el juego (sin sesión): la clave de grupo es la llave
-- ---------------------------------------------------------------------------
create or replace function public.gasa_control()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select control_activo from public.campus_ajuste where id = 1), false);
$$;

create or replace function public.gasa_grupo_por_clave(p_clave text)
returns table (id text, nombre text)
language sql
stable
security definer
set search_path = public
as $$
  select g.id, g.nombre from public.grupo g where g.clave = upper(trim(p_clave));
$$;

create or replace function public.gasa_liberados(p_clave text)
returns table (modulo text, capitulo smallint, desde timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select l.modulo, l.capitulo, l.desde
  from public.liberacion l
  join public.grupo g on g.id = l.grupo
  where g.clave = upper(trim(p_clave));
$$;

revoke all on function public.gasa_control(), public.gasa_grupo_por_clave(text), public.gasa_liberados(text) from public;
grant execute on function public.gasa_control(), public.gasa_grupo_por_clave(text), public.gasa_liberados(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Lista blanca: solo se crean cuentas del profesorado, administradores o
-- candidatos provisionados. El resto de altas fallan (el panel lo explica).
-- ---------------------------------------------------------------------------
create or replace function public.gasa_solo_autorizados()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.raw_app_meta_data ->> 'candidato_id', '') <> '' then
    return new;
  end if;
  if exists (select 1 from public.profesor where email = lower(new.email))
     or exists (select 1 from public.campus_admin where email = lower(new.email)) then
    return new;
  end if;
  raise exception 'GASA: ese correo no está en la lista del profesorado' using errcode = 'P0001';
end;
$$;

drop trigger if exists gasa_solo_autorizados on auth.users;
create trigger gasa_solo_autorizados
  before insert on auth.users
  for each row execute function public.gasa_solo_autorizados();
