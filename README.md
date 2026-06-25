# GASA — GAlileo Space Agency

**Marco narrativo gamificado, agnóstico de módulo, para los ciclos de FP de Informática del IES Galileo.**

GASA es una *piel* de novela visual sobre la realidad de FP: la XP procede de los
Indicadores de Logro (IL); el rango, el ranking, el mapa y la credencial **se derivan**
de un único log append-only de logros. Este repositorio contiene el **shell agnóstico
de módulo** (reutilizable en cualquier módulo y curso) y las **instancias de módulo**
que lo consumen.

> Documento de diseño completo: [`docs/PRDGASA.md`](docs/PRDGASA.md).
> Construir **solo** lo especificado allí. Ante ambigüedad: la opción más simple que
> cumpla el requisito, y configurable.

---

## La metáfora ↔ la realidad FP

| Narrativa GASA | Concepto FP / técnico |
|---|---|
| Agencia / misión | Curso / módulo |
| Candidato / tripulante | Alumno |
| Objetivos de misión | Resultados de Aprendizaje (RA) |
| Hitos | Criterios de Evaluación (CE) |
| Entregables / certificaciones | Indicadores de Logro (IL) |
| Rango | Nivel de progreso (gating por XP) |
| Carnet / credencial | Identidad persistente del alumno |
| Mapa de misión | Roadmap del módulo (árbol de CE/hitos) |
| Ticket | Reto / examen individual |

**Arco de curso:** 1º = *Tierra* (candidatos; capstone = lanzamiento) · 2º = *Marte*
(tripulación aterrizada; supervivencia de la colonia). La narrativa concreta de cada
módulo es **contenido parametrizable**, no código.

---

## Arquitectura (3 capas)

```
[ Frontend estático ]   Astro — novela visual, mapa, carnet, ranking + manuales
        │                desplegado en GitHub Pages
        ▼
[ Motor de ejecución en navegador ]   práctica instantánea client-side (la define cada módulo)
        │
        ▼
[ BaaS Postgres gestionado ]   estado persistente + autenticación seudónima (Supabase)
```

Dos cosas **separadas, no acopladas** (§3.1 del PRD):

- **Motor de práctica/examen** — lo aporta **cada módulo**; **no es parte del shell**.
  El shell solo necesita *registrar el intento y su resultado*.
- **Backend de estado** — *fontanería interna* (carnet, log de logros, ranking).
  **Supabase (Postgres).** El esquema de datos no depende de esta elección.

---

## Convención del monorepo (decisión cerrada — §6)

**Un solo repo, un solo `main`, organización por directorios. NO rama-por-módulo.**

El shell es un núcleo compartido del que dependen N módulos simultáneamente. La "piel"
de cada módulo es **configuración/data**, no una línea de desarrollo. `/core` se mejora
**una vez** y todos los módulos lo heredan, sin peaje de merge.

```
GalileoSpaceAgency/
├── core/                  # el shell agnóstico de módulo (única fuente de verdad)
│   ├── carnet/            #   esquema del perfil/credencial + plantilla de render
│   ├── progresion/        #   rango ↔ il ↔ xp (config: rango.json)
│   ├── mapa/              #   esquema/render del mapa de misión
│   └── ingreso/           #   banco transversal + plantilla de ficha de ingreso
├── modules/
│   └── _template/         # plantilla de instancia de módulo (copiar para crear uno nuevo)
├── data/                  # estado seudónimo versionado (si aplica) — compartido, NO ramificado
├── supabase/              # esquema de estado: migraciones SQL + RLS (se aplican en tu proyecto)
├── src/                   # app Astro que consume /core y /modules
├── docs/                  # documento de diseño (PRD)
└── (mapeo privado)        # FUERA de git, en disco del profesor (§4, §5.1)
```

- El shell está **parametrizado por `(año, planeta, módulo)`** desde el inicio.
  No se codifica nada a medida de un módulo concreto en `/core`.
- Cada módulo en `/modules/<x>` **consume** `/core` y solo aporta su parametrización:
  planeta/año, NPCs, narrativa, motor de práctica, y su `ra/ce/il/nodo_mapa`.

---

## Modelo de datos (resumen — §5)

`candidato_id` es la clave que une todo y **lo único que cruza al fichero sensible**.

- **SENSIBLE (offline, solo el profesor, NUNCA en repo ni backend):**
  `mapeo(candidato_id, nombre_real, grupo)`.
- **ESTADO (seudónimo, Supabase):** `candidato`, `logro` (append-only, el corazón del
  sistema), `diagnostico` (privado del profesor).
- **CONFIG AGNÓSTICA (`/core`, JSON):** `rango`.
- **CONFIG POR MÓDULO (`/modules/<x>`, JSON):** `ra`, `ce`, `il`, `nodo_mapa`.
- **DERIVADO (no se persiste; se calcula):** `xp_total`, `rango`, `ranking`,
  `credencial`, estado del `mapa`.

> Un solo log append-only (`logro`) es toda la mecánica. Rango, ranking, credencial y
> mapa **no se almacenan**: se derivan de `logro` + config.

---

## Privacidad (requisito duro — §4)

**Seudonimización en la puerta. El sistema nunca ve un nombre real.**

- Login = `candidato_id` (`GASA-2627-NNN`) + código de acceso. Sin email, sin PII.
- **Row-Level Security:** cada alumno lee/escribe **solo su propia fila**.
- `diagnostico` es **privado del profesor** (rol de servicio); el alumno nunca lo ve.
- El fichero `mapeo` (único cruce a identidad real) **jamás** entra en git ni en el
  backend. `.gitignore` incluye una red de seguridad para evitar subirlo por error.

---

## Estado del proyecto

🚧 **Andamiaje (v0.1).** Estructura del monorepo, convención y esqueletos de config.
Sin código funcional del Día 1 todavía. Orden de construcción en
[`docs/PRDGASA.md` §9](docs/PRDGASA.md).

## Desarrollo

```bash
npm install
npm run dev      # servidor de desarrollo Astro
npm run build    # build estático -> dist/
```

Copia `.env.example` a `.env` y rellena las credenciales de Supabase cuando toque
conectar el backend de estado. Ver [`supabase/README.md`](supabase/README.md).
