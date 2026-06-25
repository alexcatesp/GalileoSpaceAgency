# `/core` — el shell agnóstico de módulo

Esta es la **única fuente de verdad** del shell de GASA. Se mejora **una vez** y todos
los módulos lo heredan, sin peaje de merge (ver convención monorepo en el README raíz).

**Regla dura:** nada en `/core` puede estar codificado a medida de un módulo concreto.
El shell está parametrizado por `(año, planeta, módulo)`; lo específico vive en
`/modules/<x>`.

## Subdirectorios

| Dir | Responsabilidad | Estado |
|---|---|---|
| `carnet/` | Esquema del perfil/credencial + plantilla de render | 🚧 esqueleto |
| `progresion/` | `rango ↔ il ↔ xp`: config de rangos + cálculo derivado de XP/rango | 🚧 esqueleto (config lista) |
| `mapa/` | Esquema/render del mapa de misión + iluminación derivada de `logro` | 🚧 esqueleto |
| `ingreso/` | Banco transversal del diagnóstico + plantilla de la ficha de ingreso | 🚧 esqueleto |

## Qué es config y qué es código

- **Config agnóstica** (fuente de verdad en git como JSON): `progresion/rango.json`.
- **Esquemas y plantillas de render**: viven aquí y son consumidos por la app (`/src`).
- **Esquema de estado** (tablas Supabase + RLS): en `/supabase` (no en `/core`), porque
  es fontanería del backend; el esquema de datos lógico se documenta en el PRD §5.

> Andamiaje v0.1: los subdirectorios contienen READMEs y, donde aplica, la config ya
> sembrada. El render y la lógica funcional se construyen en fases posteriores (PRD §9).
