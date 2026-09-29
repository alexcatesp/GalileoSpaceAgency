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

1. Crea el proyecto en [supabase.com](https://supabase.com) (nómbralo **`gasa-iesgalileo`**
   — proyecto único reutilizable; la cohorte ya va en el `candidato_id`) y copia su
   **Reference ID** (Project Settings → General).
2. Pega ese ref en `supabase/config.toml` → `project_id = "..."`.
3. En el dashboard: **Project Settings → Integrations → GitHub** → conecta este repo
   (`alexcatesp/GalileoSpaceAgency`) y elige la rama de producción. A partir de ahí, cada
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

## Campus: panel del profesorado y liberación de capítulos

Migración `20260929120000_campus_liberacion.sql`. El panel vive en
`iesgalileo.alejandrocatalaespi.es/gasa/panel/` (su código está en el repositorio privado
`iesgalileo-2026-27`, carpeta `modulos/DAM/gasa-campus/panel/`).

- **Tablas:** `campus_admin`, `profesor`, `grupo`, `profesor_grupo` (qué módulo da cada
  profesor y en qué grupo), `liberacion` (capítulos abiertos o programados por módulo y
  grupo) y `campus_ajuste` (interruptor general `control_activo`, apagado por defecto).
- **Permisos (RLS):** cada profesor ve y cambia solo las liberaciones de sus módulos en sus
  grupos; el administrador, todo. El alumnado no lee ninguna tabla: el juego usa
  `gasa_control()`, `gasa_grupo_por_clave(clave)` y `gasa_liberados(clave)`.
- **Privacidad:** ningún correo en este repositorio (es público). El profesorado lo da de
  alta el administrador desde el panel.

### Acceso del profesorado: código de un solo uso por correo

El panel usa el OTP por correo de Supabase Auth. Para que la cuenta de un profesor se cree
sola la primera vez que entra, el registro tiene que estar **permitido**; el disparador
`gasa_solo_autorizados` en `auth.users` rechaza cualquier alta que no sea de un correo de
`profesor` o `campus_admin`, o de un candidato provisionado (con `app_metadata.candidato_id`).
Esto sustituye a la recomendación anterior de desactivar el registro.

Configuración en el dashboard (una vez):

1. **Authentication → Sign In / Providers → Email:** activa *Allow new users to sign up*.
   *Confirm email* puede quedar desactivado: la migración 0005 rechaza cualquier alta con
   contraseña, así que el profesorado solo entra con el código que recibe en su correo.
   Pon también *URL Configuration → Site URL* = `https://iesgalileo.alejandrocatalaespi.es/gasa/panel/`.
2. **Authentication → Emails → Templates:** en *Magic Link* y en *Confirm signup*, pon el
   código en el cuerpo con `{{ .Token }}` (por ejemplo: «Tu código de acceso al panel de la
   GASA es {{ .Token }}. Caduca en 10 minutos.»).
3. **Authentication → Emails → SMTP Settings:** SMTP propio con **Resend** (dominio
   `alejandrocatalaespi.es` verificado en Resend, región Ireland, con sus registros DKIM y
   `send` en el DNS de IONOS): host `smtp.resend.com`, puerto `465`, usuario `resend`,
   contraseña = la API key de Resend (permiso de envío), remitente
   `gasa@alejandrocatalaespi.es`, nombre «GASA · Galileo Space Agency». Sin SMTP propio,
   Supabase solo envía a los miembros del equipo del proyecto y con un límite muy bajo.
4. **Authentication → Sign In / Providers → Email:** *Email OTP Expiration* = 600 s.
5. **SQL Editor:** añade el primer administrador:
   `insert into public.campus_admin (email) values ('<tu correo>');`
