# `tools/provision` — provisión de candidatos (flujo del profesor)

Esto **no es parte del juego**: es la herramienta con la que el profesor da de alta la
promoción **fuera del sistema** (PRD §4.1, §9). El juego solo consume los `candidato_id`.

## Qué hace

A partir de la **orla** (CSV con `nombre_real,grupo`), por cada alumno:

1. genera un `candidato_id` opaco `GASA-<cohorte>-NNN` (PRD §4.3);
2. genera un `codigo` de acceso alfanumérico de 6 caracteres (sin caracteres ambiguos);
3. crea el usuario en **Supabase Auth** con un **email sintético no enrutable**
   (`gasa-2627-001@candidatos.gasa.local`) y el claim `app_metadata.candidato_id`
   — login = `candidato_id` + `codigo`, **sin email real, sin PII**;
4. escribe el **`mapeo`** (`candidato_id ↔ nombre_real ↔ grupo`) — **artefacto SENSIBLE**;
5. escribe el **`reparto`** (`candidato_id` + `codigo`) para entregar a cada alumno.

## Requisito duro de privacidad (PRD §4, §5.1)

> El `mapeo` es el **único** artefacto sensible y **JAMÁS** entra en git ni en el backend.

Se escribe en `--out` (por defecto `./.provision`, que está en `.gitignore`). Lo ideal es
apuntarlo a una ruta **fuera del repo** (un disco del profesor). El backend solo almacena
callsigns y resultados; el único cruce a identidad real vive en ese fichero offline.

## Uso

```bash
# 1) Prueba SIN tocar Supabase: genera IDs, códigos, mapeo y reparto.
node tools/provision/provision.mjs --orla orla.csv --dry-run --out ~/gasa-privado

# 2) Provisión real contra tu proyecto Supabase (crea los usuarios auth):
#    define las credenciales primero (ver abajo)
node tools/provision/provision.mjs --orla orla.csv --out ~/gasa-privado
```

Opciones: `--cohorte 2627` · `--inicio 1` · `--out <dir>` · `--dry-run`.

### Formato de la orla (entrada)

```csv
nombre_real,grupo
Ada Lovelace,1DAW
Alan Turing,1DAW
```

> La orla es un dato del centro y **también es sensible**: manténla fuera del repo.
> `.gitignore` incluye una red de seguridad (`orla*`, `mapeo*`) por si se copia por error.

### Credenciales (solo provisión real, no en `--dry-run`)

`service_role` es el **rol del profesor**: puede saltarse RLS y crear usuarios. **Nunca**
va al cliente ni al repo. Defínelas por entorno o en `tools/provision/.env` (gitignored):

```
SUPABASE_URL=https://TU-PROYECTO.supabase.co
SUPABASE_SERVICE_ROLE_KEY=...service_role...
```

## Salida

En `--out`:

- `mapeo_<cohorte>.csv` — **SENSIBLE**. Guardar offline. No subir a ningún sitio.
- `reparto_<cohorte>.csv` — `candidato_id` + `codigo` para repartir (cada alumno su fila).
