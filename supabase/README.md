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

🚧 `migrations/` vacío en el andamiaje v0.1. La primera migración (tablas + RLS + auth
seudónima) corresponde a la fase PRD §9.2 — fuera del alcance de este andamiaje.

## Aplicar migraciones (cuando existan)

```bash
# con la CLI de Supabase, contra tu proyecto:
supabase link --project-ref <tu-ref>
supabase db push
```
