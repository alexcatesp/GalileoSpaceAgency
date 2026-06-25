# `/supabase` — backend de estado (Postgres)

Esquema del **estado del juego** y su seguridad. **Fontanería interna**: el alumno no lo
ve ni lo toca (PRD §3.1). La tecnología del backend es **independiente de la del módulo**;
si se sustituyera el BaaS, el esquema lógico (PRD §5) se conserva.

> **Decisión de esta fase:** las migraciones viven en git (`migrations/`) y **se aplican
> en tu propio proyecto Supabase**. El andamiaje **no provisiona** nada ni contiene
> credenciales. Crea el proyecto, copia `.env.example` → `.env` y rellena
> `PUBLIC_SUPABASE_URL` / `PUBLIC_SUPABASE_ANON_KEY`.

## Esquema lógico a implementar (PRD §5.2)

```
candidato(candidato_id PK, callsign, avatar_id, alta_ts)
logro(id PK, candidato_id FK, il_id FK, nivel, xp, ts)   -- LOG append-only, el corazón
diagnostico(candidato_id FK, score_transversal, score_especifico)  -- privado del profesor
```

## Seguridad — requisito duro (PRD §4.2)

- **Auth seudónima:** login = `candidato_id` (`GASA-2627-NNN`) + código de acceso. Sin
  email, sin nombre, sin PII.
- **Row-Level Security (RLS):** cada alumno lee/escribe **solo su propia fila** de
  `candidato` y `logro`.
- `logro` es **append-only**: sin UPDATE ni DELETE; cada certificación es una fila nueva
  (auditable, versionable).
- `diagnostico` es **privado del profesor**: legible solo por el rol de servicio/profesor,
  nunca por el alumno.
- La clave `anon` es segura en el cliente **porque** RLS protege el acceso. La
  `service_role` (profesor) **nunca** va al cliente ni al repo.

## Estado

✅ Migración inicial en `migrations/20260625000000_estado_inicial.sql`: tablas
`candidato` / `logro` / `diagnostico` + RLS + helper de auth seudónima (PRD §9.2).

## Aplicar el esquema — integración GitHub → Supabase

Este repo está preparado para que **Supabase aplique las migraciones solo** al hacer
push. Pasos (una vez):

1. Crea el proyecto en [supabase.com](https://supabase.com) y copia su **Reference ID**
   (Project Settings → General).
2. Pega ese ref en `supabase/config.toml` → `project_id = "..."`.
3. En el dashboard: **Project Settings → Integrations → GitHub** → conecta este repo
   (`alexcatesp/iesgalileo_2627`) y elige la rama de producción. A partir de ahí, cada
   push con migraciones nuevas se aplica a la BD.
4. Copia `.env.example` → `.env` y rellena `PUBLIC_SUPABASE_URL` /
   `PUBLIC_SUPABASE_ANON_KEY` (Project Settings → API).

> Convención de migraciones: ficheros `migrations/<timestamp>_nombre.sql`. Supabase
> ejecuta cada una **una sola vez** (las registra por su `<timestamp>`). Para un cambio
> de esquema, añade un fichero nuevo; no edites uno ya aplicado.

### Alternativa: CLI manual

```bash
supabase link --project-ref <tu-ref>
supabase db push
```

## Configuración del dashboard (auth) — importante

`config.toml` solo afecta al entorno local. En el **proyecto hospedado**, ajusta a mano:

- **Authentication → Providers → Email**: deja el proveedor Email activo (el login usa
  email sintético + contraseña), y **desactiva "Allow new users to sign up"** — los
  usuarios los crea la provisión con `service_role`, no el registro público.
- No hace falta SMTP ni confirmaciones: la provisión crea los usuarios con
  `email_confirm: true` vía Admin API.

## Provisión de candidatos (NO la hace la integración)

La integración solo aplica el **esquema**. Dar de alta los `candidato_id` + códigos con
su claim `app_metadata.candidato_id` es trabajo de `tools/provision/provision.mjs`
(usa `service_role` en local). Ver [`tools/provision/README.md`](../tools/provision/README.md).
