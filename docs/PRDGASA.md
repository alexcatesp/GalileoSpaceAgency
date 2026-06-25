# Documento de requisitos — Sistema GASA

**Repositorio destino:** `ies-galileo-26-27`
**Destinatario:** Claude Code (construcción del andamiaje y la v1)
**Autor del diseño:** profesor (IES Galileo)
**Estado:** diseño cerrado; pendiente de construir

---

## 0. Propósito de este documento

GASA (GAlileo Space Agency) es un **marco narrativo gamificado, agnóstico de módulo**, para los ciclos de FP de Informática del IES Galileo. Este documento especifica la arquitectura, el modelo de datos, el modelo de privacidad y el flujo del Día 1 con precisión suficiente para construir la v1 **sin volver a derivar el diseño**.

El alcance de este documento es **el shell agnóstico de módulo**. Todo lo específico de un módulo concreto (tecnología de práctica, contenido, narrativa, NPCs, indicadores de logro reales) es contenido parametrizable que se instancia aparte y **no se especifica aquí**.

No construyas nada que no esté aquí. Si algo es ambiguo, prefiere la opción más simple que cumpla el requisito y déjalo configurable.

---

## 1. Glosario (la metáfora ↔ la realidad FP)

La capa narrativa es una piel sobre conceptos de FP. La equivalencia es estricta y es la columna vertebral del sistema:

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
| Manual de misión | Apuntes / material del módulo |
| Ticket | Reto / examen individual |
| Transmisión / all-hands | Actividad en pantalla de clase |

**Arco de curso (decisión tomada):**
- **1º — Tierra:** los alumnos son *candidatos* a astronauta. La agencia opera en Tierra y proyecta el lanzamiento a final de curso (el lanzamiento = proyecto integrador / capstone).
- **2º — Marte:** la tripulación ha aterrizado; los retos giran en torno a la supervivencia de la colonia, adaptados a los módulos de 2º.

El marco debe encajar con **cualquier módulo**: la narrativa concreta de cada módulo es contenido parametrizable, no código.

---

## 2. Objetivos y no-objetivos

### Objetivos (v1)
1. **Capa persistente agnóstica de módulo (el "shell"):** carnet, avatar, rango, mapa, ranking, identidad del candidato. Reutilizable en cualquier módulo y curso.
2. **Acceso del alumno desde cualquier sitio y en cualquier momento**, con su avance en vivo.
3. **Material del módulo (manuales de misión)** integrado y consultable como contenido estático.
4. **Práctica real con feedback inmediato**, y registro persistente de los intentos (la tecnología concreta de práctica la define cada módulo; ver §3.1).
5. **Flujo del Día 1** ("Día de ingreso"): ficha de ingreso (diagnóstico) + alta (avatar + credencial + perfil), todo bajo un ID seudónimo.
6. **El juego es el instrumento de evaluación:** la XP procede de los IL; rango/ranking/mapa se *derivan* del registro de logros.

### No-objetivos (explícitos — no construir)
- **Aventura gráfica point-and-click.** Es una trampa de coste (arte por escena, puzzles de inventario que compiten con la pedagogía). El formato es **novela visual**: retrato de personaje + transmisión/diálogo → tarea real → resolución narrativa. El mapa es un plano estático que se rellena, no un escenario navegable.
- **Editor de avatar.** Avatar de **galería cerrada** (set de retratos predefinidos). Personalización capada.
- **Tiempo real estricto / colaboración multiusuario en vivo** más allá de lo que el backend gestionado dé de serie. No montar websockets ni sincronización propia en v1.
- **Backend a medida** (servidor propio + hosting + auth propios + devops). Usar BaaS gestionado.

---

## 3. Arquitectura (decisión tomada)

Tres capas. **No** es una app estática (eso impediría el acceso en vivo y el registro de práctica). **No** es un backend a medida (reintroduce devops).

```
[ Frontend estático ]   app (novela visual, mapa, carnet, ranking) + manuales (material del módulo)
        │                servido en GitHub Pages / Vercel
        ▼
[ Motor de ejecución en navegador ]   práctica instantánea client-side, según el módulo
        │
        ▼
[ BaaS Postgres gestionado ]   estado persistente + autenticación seudónima  (Supabase)
```

### 3.1 Principio: separar el motor de práctica del backend de estado

Son **dos cosas distintas**; no acoplarlas:

**Motor de práctica/examen — donde el alumno trabaja.** Lo define **cada módulo** según su tecnología y su pedagogía; **no forma parte del shell**. Requisitos agnósticos que el shell sí impone:
- **Ejecución client-side siempre que la tecnología del módulo lo permita** (runner en el navegador): práctica instantánea, sin servidor.
- Donde no sea posible ejecutar en cliente, la práctica se valida contra un **entorno real aportado** (equipo de clase o contenedor) mediante un **script verificador** que compara el resultado del alumno con el esperado.
- **El examen siempre se valida contra el entorno real del módulo**, no contra el sandbox de práctica (puede haber divergencias de fidelidad entre ambos).
- Sea cual sea el motor, la **ejecución es del módulo**; lo que el shell necesita es **registrar el intento y su resultado** (ver §3.2).

**Backend de estado — donde vive el juego** (carnet, log de logros, ranking). Es **fontanería interna**; el alumno no lo ve ni lo toca, y su tecnología es **independiente de la del módulo**. **Decisión: Supabase (Postgres).** El esquema de datos (§5) no depende de esta elección; si se sustituyera el BaaS, el esquema se conserva.

### 3.2 Reparto de responsabilidades por requisito
- **Manuales (material del módulo):** estáticos (HTML/Markdown). **Sin backend.** Aportados por el profesor como contenido.
- **Ejecutar práctica:** **cliente**, cuando la tecnología del módulo lo permita. Sin backend.
- **Registrar el intento / el logro:** **backend** (Supabase).
- **Ver avance desde cualquier sitio:** **backend** (estado hospedado + identidad).

---

## 4. Modelo de identidad y privacidad (decisión tomada — requisito duro)

**Principio: seudonimización en la puerta. El sistema nunca ve un nombre real.** Toda la superficie sensible se reduce a un único fichero offline.

### 4.1 Flujo de provisión
1. El profesor genera la lista de **`candidato_id`** a partir de la orla (dato del centro).
2. En un **fichero de mapeo privado y offline** (`mapeo`), el profesor guarda `candidato_id ↔ nombre_real ↔ grupo`. **Este fichero JAMÁS entra en el repositorio ni en el backend.** Es el único artefacto sensible.
3. Se reparte a cada alumno su `candidato_id` + un **código de acceso** generado.
4. La **ficha de ingreso** (un solo formulario) se rellena **bajo ese `candidato_id`**. El formulario **nunca** captura el nombre real.

### 4.2 Autenticación
- Login = `candidato_id` + código de acceso. **Sin email, sin nombre, sin PII.**
- **Row-Level Security (RLS):** cada alumno lee/escribe **solo su propia fila**.
- La tabla `diagnostico` es **privada del profesor**: legible solo por rol de servicio/profesor, nunca por el alumno.
- Postura: aunque hubiera fuga del backend, expone callsigns + resultados de actividad, no personas. El único cruce a identidad real no sale del disco del profesor.

### 4.3 Formato de `candidato_id`
Opaco, sin PII, estable todo el ciclo:
```
GASA-2627-NNN      p. ej. GASA-2627-001
```
(`2627` = cohorte 26-27; `NNN` = secuencial). El código de acceso: alfanumérico corto (p. ej. 6 caracteres), generado en la provisión.

---

## 5. Modelo de datos (decisión tomada)

`candidato_id` es la clave que une todo y **lo único que cruza al fichero sensible**.

### 5.1 SENSIBLE — offline, solo el profesor, NUNCA en repo ni backend
```
mapeo(candidato_id PK, nombre_real, grupo)
```

### 5.2 ESTADO — seudónimo, en el backend (Supabase / Postgres)
```
candidato(
  candidato_id   PK,
  callsign,                 -- alias elegido en el ingreso
  avatar_id,                -- referencia a asset de galería (no imagen personal)
  alta_ts
)

logro(                      -- LOG append-only; el corazón del sistema
  id             PK,
  candidato_id   FK -> candidato,
  il_id          FK -> il,
  nivel,                    -- Suficiente | Notable | Excelente
  xp,
  ts
)

diagnostico(               -- privado del profesor; NO es XP, NO es ranking
  candidato_id   FK -> candidato,
  score_transversal,
  score_especifico
)
```
- `logro` es **append-only**: no se actualiza ni se borra; cada certificación obtenida es una fila nueva. Es auditable y versionable.
- RLS: el alumno solo ve sus filas de `candidato` y `logro`; `diagnostico` solo el profesor.

### 5.3 CONFIG AGNÓSTICA — en `/core` (fuente de verdad en git como JSON/YAML; sembrada o leída por la app)
```
rango(
  rango_id   PK,
  nombre,                   -- Recluta | Especialista | Oficial | Jefe de Misión
  xp_umbral,                -- XP mínima para alcanzar el rango
  orden
)
```

### 5.4 CONFIG POR MÓDULO — en `/modules/<x>` (mismo esquema, contenido propio)
```
ra(ra_id PK, descripcion)

ce(ce_id PK, ra_id FK, descripcion)                 -- hitos del mapa

il(il_id PK, ce_id FK,
   nivel,                                           -- Suficiente | Notable | Excelente
   xp,                                              -- XP que otorga ese IL a ese nivel
   descripcion)                                     -- certificaciones

nodo_mapa(nodo_id PK, ce_id FK, titulo, depende_de, x, y)   -- depende_de = prerequisito
```
**Indicadores de logro (IL):** son la unidad de evaluación y la fuente de XP. Cada IL cuelga de un CE, está graduado en tres niveles (Suficiente / Notable / Excelente), tiene una **descripción concreta y observable** de lo que el candidato debe acreditar, y una XP asociada a su nivel. Un mismo CE se cubre con varios IL. El contenido real de los IL es propio de cada módulo y se aporta al instanciar el módulo; el shell solo asume esta estructura.

### 5.5 DERIVADO — NO se almacena; se calcula en consulta/build
```
xp_total(candidato)  = Σ logro.xp
rango(candidato)     = máx rango con xp_umbral ≤ xp_total
ranking              = orden por xp_total  (ver §8: por defecto NO es la métrica principal)
credencial           = candidato + sus logros (huecos de certificación rellenos)
mapa                 = nodos iluminados según los CE con IL logrados
```
**Requisito:** rango, ranking, credencial y estado del mapa **no se persisten**; se derivan de `logro` + config. Un solo log append-only es toda la mecánica.

---

## 6. Estructura del repositorio (decisión tomada)

**Monorepo, un solo `main`, directorios. NO rama-por-módulo.** (Rama-por-módulo es un anti-patrón aquí: el shell es un núcleo compartido del que dependen N módulos simultáneos; cada mejora del shell exigiría mergear en cada rama. La piel de cada módulo es *configuración/data*, no una línea de desarrollo.)

```
ies-galileo-26-27/
├── core/                      # el shell agnóstico de módulo
│   ├── carnet/                #   esquema del perfil/credencial + plantilla de render
│   ├── progresion/            #   rango ↔ il ↔ xp  (config: rango)
│   ├── mapa/                  #   esquema/render del mapa de misión
│   └── ingreso/               #   banco transversal + plantilla de ficha de ingreso
├── modules/
│   ├── <modulo-a>/            #   instancia de módulo: config (ra/ce/il/nodo) + contenido (NPCs, narrativa, motor de práctica)
│   └── <modulo-b>/            #   otro módulo, misma identidad de tripulante
├── data/                      # estado seudónimo (si se versiona algo) — compartido, NO ramificado
└── (mapeo privado)            # FUERA de git, en disco del profesor
```
- `/core` es la **única fuente de verdad** del shell: se mejora una vez y todos los módulos lo heredan, sin peaje de merge.
- Cada módulo en `/modules/<x>` **consume** `/core` y solo aporta su parametrización: planeta/año, NPCs, narrativa, motor de práctica, y su `ra/ce/il/nodo_mapa`.
- El shell debe estar **parametrizado por `(año, planeta, módulo)`** desde el inicio. No codificar nada a medida de un módulo concreto en `/core`.

---

## 7. Flujo del Día 1 — "Día de ingreso en la GASA" (primer feature concreto)

La parte **transversal es fija** (vive en `/core/ingreso/`); la **específica se parametriza** por módulo.

1. **Transmisión de bienvenida** (pantalla de clase, ~10 min). Apertura en frío: la GASA convoca una nueva promoción de *candidatos* (aún no astronautas — quita presión al principiante). Objetivo de la temporada (1º = lanzamiento; 2º = supervivencia).
2. **Dossier de misión = la programación** (~25 min). Reencuadre: RA→Objetivos, CE→Hitos, IL→Entregables/certificaciones. Se muestra el **mapa** (plano con nodos bloqueados): ven el viaje entero el Día 1. *Nota: presentar la programación el Día 1 es obligatorio en FP — esto lo disfraza, no añade trabajo.*
3. **Ficha de ingreso = examen diagnóstico** (en su PC, ~40 min). Dos bloques:
   - **Transversal** (agnóstico, fijo en el shell): razonamiento lógico, patrones, pensamiento con datos/conjuntos.
   - **Específico** (parametrizado por módulo): conocimiento previo del dominio del módulo.
   - **Regla dura:** diagnóstico **para el profesor (privado)**, sabor para el alumno. **Todos embarcan como Recluta con XP 0**, sea cual sea la nota. La nota de ingreso **no es XP ni ranking** (no sembrar una casta el Día 1).
4. **Alta en la agencia** (~35 min): genera **perfil + avatar + credencial**.
   - **La ficha de ingreso ES el formulario de alta.** Un único formulario hace el examen *y* recoge `callsign` + elección de avatar. Una entrada → crea `candidato` + `diagnostico` + credencial renderizada.
   - **Avatar de galería**, no editor.

**Mínimo viable del Día 1** (lo primero a construir): un formulario bajo `candidato_id` (transversal listo + hueco parametrizable para lo específico) que alimente una **plantilla de credencial/perfil**.

---

## 8. Modos de juego y métrica de progreso

### Dos modos (mismo estado compartido)
- **Público (pantalla de clase):** transmisiones, all-hands, duelos/retos en vivo, jefes finales (toda la clase contra un problema), repaso tipo Kahoot, revelado de progreso, briefings narrativos de fase.
- **Individual (PC del alumno):** "tickets" de misión y exámenes con autocorrección. Cada ticket superado → certificación (fila en `logro`).

### Métrica de progreso (DECISIÓN ABIERTA — default seguro)
El ranking puro por XP **desmotiva a la cola** y, en una misión cooperativa, rompe la ficción.
- **Default a implementar:** **barra de progreso colectiva de la misión** como métrica **principal** (la colonia/lanzamiento avanza entre todos), y **progreso individual contra uno mismo** (`certificaciones obtenidas / total`) como secundaria. El ranking competitivo por XP queda **desactivado por defecto**, disponible como opción configurable (p. ej. ligas por tramos).
- Hacerlo **configurable** (flag): `progreso_modo = {colaborativo | ligas | ranking_global}`. No hardcodear ranking global.

---

## 9. Orden de construcción sugerido (para Claude Code)

1. **Andamiaje del repo** con la estructura de §6 y un README que fije la convención monorepo/directorios.
2. **`/core` — esquema de estado** (Supabase): `candidato`, `logro`, `diagnostico` + **RLS** ("cada uno ve lo suyo"; `diagnostico` solo profesor) + **auth seudónima** (`candidato_id` + código, sin PII).
3. **`/core/progresion`** — `rango` (Recluta→Especialista→Oficial→Jefe de Misión) + cálculo derivado de `xp_total` y rango.
4. **`/core/ingreso`** — formulario único de ingreso (examen transversal + callsign + selección de avatar) → crea perfil + `diagnostico` + **plantilla de credencial** renderizada.
5. **Galería de avatares** (assets cerrados) + render de credencial.
6. **`/core/mapa`** — render del mapa desde `nodo_mapa` + estado de iluminación derivado de `logro`.
7. **Contrato de práctica** — definir la interfaz agnóstica por la que un módulo registra un intento/resultado en el backend (independiente del motor de práctica que el módulo provea). Integrar la ejecución client-side queda del lado del módulo.
8. **Integración de manuales** (material estático del módulo) en el frontend.
9. **Primera instancia de módulo** en `/modules/<x>` — sembrar `ra/ce/il/nodo_mapa` (los IL los aporta el profesor) y la narrativa/NPCs de la temporada.

La provisión de `candidato_id` y el fichero `mapeo` los hace el profesor **fuera del sistema**; el sistema solo consume los IDs.

---

## 10. Resumen de decisiones

| Tema | Decisión |
|---|---|
| Arquitectura | Frontend estático + ejecución client-side (según módulo) + Supabase (estado). No app estática pura; no backend a medida |
| Motor de práctica/examen | Lo define cada módulo; ejecución en cliente cuando sea posible; examen validado contra entorno real del módulo. No forma parte del shell |
| Motor del estado del juego | Supabase (Postgres), interno; independiente de la tecnología del módulo |
| Privacidad | Seudonimización en la puerta; `mapeo` offline único artefacto sensible; RLS; sin PII en backend |
| Identidad | `candidato_id` (`GASA-2627-NNN`) + código de acceso |
| Modelo de datos | `candidato` + `logro` (append-only) + `diagnostico` (privado); rango/ranking/credencial/mapa **derivados** |
| Repo | Monorepo, un `main`, directorios `/core` + `/modules/<x>`. NO rama-por-módulo |
| Avatar | Galería cerrada, no editor |
| Formato narrativo | Novela visual, NO point-and-click |
| Métrica de progreso | Default colaborativo (progreso colectivo + vs-uno-mismo); ranking competitivo configurable, off por defecto |
| Día 1 | Ficha de ingreso = formulario de alta; diagnóstico privado; todos Recluta XP 0 |
| Diagnóstico de ingreso | No es XP ni ranking |

---

*Fin del documento. Construir solo lo aquí especificado; ante ambigüedad, la opción más simple que cumpla el requisito, y configurable.*
