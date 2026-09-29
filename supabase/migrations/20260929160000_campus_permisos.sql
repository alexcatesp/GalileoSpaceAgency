-- ===========================================================================
-- GASA — Campus: permisos de ejecución ajustados
-- Migración 0004
--
-- Supabase concede por defecto EXECUTE a anon y authenticated en las funciones
-- nuevas del esquema public, así que «revoke … from public» no basta. Las
-- funciones ya comprobaban quién llama, pero por defensa en profundidad:
--   · las internas no las puede llamar nadie desde fuera;
--   · las del profesorado, solo con sesión (authenticated);
--   · las del juego siguen abiertas (anon) porque la clave o el token son la llave.
-- ===========================================================================

-- internas
revoke execute on function public.gasa_sesion(text), public.gasa_codigo_nuevo(), public.gasa_puede_grupo(text),
                           public.gasa_solo_autorizados()
  from anon, authenticated;

-- del profesorado: solo con sesión
revoke execute on function public.gasa_crear_alumnos(text, integer), public.gasa_codigo_alumno(text), public.gasa_borrar_alumno(text),
                           public.gasa_alumnos_grupo(text), public.gasa_progreso_grupo(text),
                           public.gasa_es_admin(), public.gasa_puede(text, text)
  from anon;
