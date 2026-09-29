-- ===========================================================================
-- GASA — Campus: el profesorado solo entra con código de un solo uso
-- Migración 0005
--
-- Si en Auth está desactivado «Confirm email», cualquiera que conozca el correo
-- de un profesor de la lista podría registrarse con ese correo y una contraseña
-- inventada (con la clave pública) antes de que el profesor entre por primera
-- vez, y quedarse con su acceso. El código por correo no tiene ese riesgo,
-- porque exige recibirlo. Por eso la lista blanca rechaza ahora las altas con
-- contraseña, salvo los candidatos provisionados por el profesor (PRD).
-- ===========================================================================

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
  if coalesce(new.encrypted_password, '') <> '' then
    raise exception 'GASA: el panel solo admite el acceso con código por correo' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.profesor where email = lower(new.email))
     or exists (select 1 from public.campus_admin where email = lower(new.email)) then
    return new;
  end if;
  raise exception 'GASA: ese correo no está en la lista del profesorado' using errcode = 'P0001';
end;
$$;

revoke execute on function public.gasa_solo_autorizados() from anon, authenticated;
