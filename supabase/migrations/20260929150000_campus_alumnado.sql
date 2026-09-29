-- ===========================================================================
-- GASA — Campus: alumnado seudónimo y partidas guardadas
-- Migración 0003
--
-- Principio del PRD (§4): seudonimización en la puerta. El servidor NUNCA ve un
-- nombre ni un correo del alumnado. Cada alumno tiene un identificador opaco
-- (GASA-2627-NNN) y un código de acceso corto. El profesor da de alta a su
-- grupo desde el panel: los nombres se quedan en su navegador y solo él guarda
-- el fichero que une cada identificador con su alumno.
--
-- El alumnado no usa Supabase Auth: entra con identificador + código mediante
-- funciones SECURITY DEFINER que devuelven un token de sesión. Todo el acceso a
-- estas tablas pasa por funciones; ningún rol lee las tablas directamente.
-- ===========================================================================

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.alumno (
  candidato_id    text primary key check (candidato_id ~ '^GASA-[0-9]{4}-[0-9]{3}$'),
  grupo           text not null references public.grupo (id) on delete cascade on update cascade,
  codigo_hash     text not null,
  fallos          smallint not null default 0,
  bloqueado_hasta timestamptz,
  alta_ts         timestamptz not null default now(),
  creado_por      text not null
);
comment on table public.alumno is
  'Alumnado seudónimo: identificador opaco, grupo y código cifrado. Sin nombres ni correos.';

create table if not exists public.sesion_alumno (
  token_hash   text primary key,
  candidato_id text not null references public.alumno (candidato_id) on delete cascade,
  creada       timestamptz not null default now(),
  usada        timestamptz not null default now()
);
comment on table public.sesion_alumno is 'Sesiones del alumnado (solo se guarda el hash del token).';

create table if not exists public.partida (
  candidato_id text not null references public.alumno (candidato_id) on delete cascade,
  edificio     text not null check (edificio in ('gasa-0485', 'gasa-0484', 'gasa-0483', 'gasa-0373', 'gasa-0487', 'gasa-campus')),
  estado       jsonb not null check (pg_column_size(estado) < 65536),
  actualizado  timestamptz not null default now(),
  primary key (candidato_id, edificio)
);
comment on table public.partida is 'Progreso del juego por alumno y edificio (capítulos, insignias, simulador).';

alter table public.alumno        enable row level security;
alter table public.sesion_alumno enable row level security;
alter table public.partida       enable row level security;
revoke all on public.alumno, public.sesion_alumno, public.partida from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Ayudas internas
-- ---------------------------------------------------------------------------
create or replace function public.gasa_puede_grupo(p_grupo text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.gasa_es_admin()
      or exists (select 1 from public.profesor_grupo where email = public.gasa_email() and grupo = p_grupo);
$$;

create or replace function public.gasa_codigo_nuevo()
returns text
language plpgsql
volatile
set search_path = public, extensions
as $$
declare
  alfabeto constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';  -- sin 0/O ni 1/I/L
  b bytea := extensions.gen_random_bytes(6);
  s text := '';
begin
  for i in 0..5 loop
    s := s || substr(alfabeto, (get_byte(b, i) % length(alfabeto)) + 1, 1);
  end loop;
  return s;
end;
$$;

create or replace function public.gasa_sesion(p_token text)
returns text
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v_id text;
begin
  update public.sesion_alumno
     set usada = now()
   where token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex')
     and usada > now() - interval '180 days'
  returning candidato_id into v_id;
  if v_id is null then
    raise exception 'GASA: sesión caducada o no válida' using errcode = 'P0001';
  end if;
  return v_id;
end;
$$;

revoke all on function public.gasa_puede_grupo(text), public.gasa_codigo_nuevo(), public.gasa_sesion(text) from public;

-- ---------------------------------------------------------------------------
-- Profesorado (sesión de Supabase Auth): alta, códigos, lista y progreso
-- ---------------------------------------------------------------------------
create or replace function public.gasa_crear_alumnos(p_grupo text, p_n integer)
returns table (candidato_id text, codigo text)
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v_cohorte text := to_char(current_date - interval '8 months', 'YY') || to_char(current_date + interval '4 months', 'YY');
  v_sig integer;
  v_codigo text;
  v_id text;
begin
  if not public.gasa_puede_grupo(p_grupo) then
    raise exception 'GASA: no tienes permiso sobre el grupo %', p_grupo using errcode = '42501';
  end if;
  if p_n is null or p_n < 1 or p_n > 60 then
    raise exception 'GASA: se pueden dar de alta entre 1 y 60 alumnos a la vez' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtext('gasa_alumnos'));
  select coalesce(max(substr(a.candidato_id, 11, 3)::integer), 0) + 1 into v_sig
    from public.alumno a where a.candidato_id like 'GASA-' || v_cohorte || '-%';
  for i in 1..p_n loop
    v_id := 'GASA-' || v_cohorte || '-' || lpad((v_sig + i - 1)::text, 3, '0');
    v_codigo := public.gasa_codigo_nuevo();
    insert into public.alumno (candidato_id, grupo, codigo_hash, creado_por)
      values (v_id, p_grupo, extensions.crypt(v_codigo, extensions.gen_salt('bf')), public.gasa_email());
    candidato_id := v_id; codigo := v_codigo;
    return next;
  end loop;
end;
$$;

create or replace function public.gasa_codigo_alumno(p_candidato text)
returns text
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v_grupo text;
  v_codigo text := public.gasa_codigo_nuevo();
begin
  select grupo into v_grupo from public.alumno where candidato_id = p_candidato;
  if v_grupo is null or not public.gasa_puede_grupo(v_grupo) then
    raise exception 'GASA: no tienes permiso sobre ese alumno' using errcode = '42501';
  end if;
  update public.alumno set codigo_hash = extensions.crypt(v_codigo, extensions.gen_salt('bf')), fallos = 0, bloqueado_hasta = null
   where candidato_id = p_candidato;
  delete from public.sesion_alumno where candidato_id = p_candidato;  -- cierra sus sesiones abiertas
  return v_codigo;
end;
$$;

create or replace function public.gasa_borrar_alumno(p_candidato text)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_grupo text;
begin
  select grupo into v_grupo from public.alumno where candidato_id = p_candidato;
  if v_grupo is null or not public.gasa_puede_grupo(v_grupo) then
    raise exception 'GASA: no tienes permiso sobre ese alumno' using errcode = '42501';
  end if;
  delete from public.alumno where candidato_id = p_candidato;
end;
$$;

create or replace function public.gasa_alumnos_grupo(p_grupo text)
returns table (candidato_id text, alta_ts timestamptz, ultima timestamptz, bloqueado boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.gasa_puede_grupo(p_grupo) then
    raise exception 'GASA: no tienes permiso sobre el grupo %', p_grupo using errcode = '42501';
  end if;
  return query
    select a.candidato_id, a.alta_ts,
           (select max(p.actualizado) from public.partida p where p.candidato_id = a.candidato_id),
           coalesce(a.bloqueado_hasta > now(), false)
      from public.alumno a where a.grupo = p_grupo order by a.candidato_id;
end;
$$;

-- el profesorado solo ve el progreso de los edificios de los módulos que imparte en ese grupo
create or replace function public.gasa_progreso_grupo(p_grupo text)
returns table (candidato_id text, edificio text, estado jsonb, actualizado timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.gasa_puede_grupo(p_grupo) then
    raise exception 'GASA: no tienes permiso sobre el grupo %', p_grupo using errcode = '42501';
  end if;
  return query
    select p.candidato_id, p.edificio, p.estado, p.actualizado
      from public.partida p
      join public.alumno a on a.candidato_id = p.candidato_id
     where a.grupo = p_grupo
       and (public.gasa_es_admin()
            or exists (select 1 from public.profesor_grupo pg
                        where pg.email = public.gasa_email() and pg.grupo = p_grupo
                          and p.edificio = 'gasa-' || pg.modulo));
end;
$$;

revoke all on function public.gasa_crear_alumnos(text, integer), public.gasa_codigo_alumno(text), public.gasa_borrar_alumno(text),
                       public.gasa_alumnos_grupo(text), public.gasa_progreso_grupo(text) from public;
grant execute on function public.gasa_crear_alumnos(text, integer), public.gasa_codigo_alumno(text), public.gasa_borrar_alumno(text),
                          public.gasa_alumnos_grupo(text), public.gasa_progreso_grupo(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Alumnado (sin sesión de Supabase): entrar, leer y guardar su partida, salir
-- ---------------------------------------------------------------------------
create or replace function public.gasa_alumno_entrar(p_candidato text, p_codigo text)
returns table (token text, grupo text, grupo_nombre text, clave text)
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  a public.alumno%rowtype;
  v_token text;
begin
  select * into a from public.alumno where candidato_id = upper(trim(p_candidato));
  if not found then
    raise exception 'GASA: identificador o código incorrectos' using errcode = 'P0001';
  end if;
  if a.bloqueado_hasta is not null and a.bloqueado_hasta > now() then
    raise exception 'GASA: demasiados intentos; espera unos minutos' using errcode = 'P0001';
  end if;
  if a.codigo_hash <> extensions.crypt(upper(trim(coalesce(p_codigo, ''))), a.codigo_hash) then
    update public.alumno
       set fallos = fallos + 1,
           bloqueado_hasta = case when fallos + 1 >= 8 then now() + interval '15 minutes' else bloqueado_hasta end
     where candidato_id = a.candidato_id;
    raise exception 'GASA: identificador o código incorrectos' using errcode = 'P0001';
  end if;
  update public.alumno set fallos = 0, bloqueado_hasta = null where candidato_id = a.candidato_id;
  v_token := encode(extensions.gen_random_bytes(24), 'hex');
  insert into public.sesion_alumno (token_hash, candidato_id)
    values (encode(extensions.digest(v_token, 'sha256'), 'hex'), a.candidato_id);
  return query select v_token, g.id, g.nombre, g.clave from public.grupo g where g.id = a.grupo;
end;
$$;

create or replace function public.gasa_partidas(p_token text)
returns table (edificio text, estado jsonb, actualizado timestamptz)
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_id text := public.gasa_sesion(p_token);
begin
  return query select p.edificio, p.estado, p.actualizado from public.partida p where p.candidato_id = v_id;
end;
$$;

create or replace function public.gasa_guardar_partida(p_token text, p_edificio text, p_estado jsonb)
returns timestamptz
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_id text := public.gasa_sesion(p_token);
  v_ts timestamptz := now();
begin
  insert into public.partida (candidato_id, edificio, estado, actualizado)
    values (v_id, p_edificio, p_estado, v_ts)
  on conflict (candidato_id, edificio) do update set estado = excluded.estado, actualizado = excluded.actualizado;
  return v_ts;
end;
$$;

create or replace function public.gasa_alumno_salir(p_token text)
returns void
language sql
volatile
security definer
set search_path = public, extensions
as $$
  delete from public.sesion_alumno where token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex');
$$;

revoke all on function public.gasa_alumno_entrar(text, text), public.gasa_partidas(text),
                       public.gasa_guardar_partida(text, text, jsonb), public.gasa_alumno_salir(text) from public;
grant execute on function public.gasa_alumno_entrar(text, text), public.gasa_partidas(text),
                          public.gasa_guardar_partida(text, text, jsonb), public.gasa_alumno_salir(text) to anon, authenticated;
