# `/core/ingreso` — Día de ingreso en la GASA

La parte **transversal del Día 1 es fija** y vive aquí. Lo **específico se parametriza**
por módulo (`/modules/<x>`).

## El formulario único (PRD §7)

> **La ficha de ingreso ES el formulario de alta.** Un único formulario hace el examen
> *y* recoge `callsign` + elección de avatar. Una entrada → crea `candidato` +
> `diagnostico` + credencial renderizada.

Dos bloques en el diagnóstico:

- **Transversal** (agnóstico, **fijo en el shell**, aquí): razonamiento lógico, patrones,
  pensamiento con datos/conjuntos.
- **Específico** (parametrizado por módulo): conocimiento previo del dominio. Lo aporta
  `/modules/<x>`.

## Reglas duras

- El formulario se rellena **bajo `candidato_id`** y **NUNCA captura el nombre real**
  (PRD §4.1).
- Diagnóstico **para el profesor (privado)**, sabor para el alumno. La tabla
  `diagnostico` solo la lee el profesor (RLS).
- **Todos embarcan como Recluta con XP 0**, sea cual sea la nota. **El diagnóstico no es
  XP ni ranking** (PRD §7.3) — no sembrar una casta el Día 1.

## Contenido (andamiaje v0.1)

- `banco_transversal.json` — banco de ítems transversales (🚧 pendiente de sembrar).
- Plantilla de la ficha de ingreso (🚧 pendiente, PRD §9.4).

> **Mínimo viable del Día 1** (primer feature funcional, fuera del alcance de este
> andamiaje): un formulario bajo `candidato_id` (transversal listo + hueco
> parametrizable para lo específico) que alimente la plantilla de credencial/perfil.
