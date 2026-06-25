# `/core/progresion` — rango ↔ il ↔ xp

Config y lógica de progresión del shell. Mapea la XP acumulada a un **rango**.

## Config

- [`rango.json`](rango.json) — escala de rangos (`Recluta → Especialista → Oficial →
  Jefe de Misión`). **Fuente de verdad en git** (PRD §5.3).
- [`rango.schema.json`](rango.schema.json) — esquema del fichero de config.

> ⚠️ Los `xp_umbral` actuales (0 / 100 / 300 / 600) son **valores placeholder**
> configurables. Se calibran cuando se conozca la XP total repartida por los IL de los
> módulos reales. El Día 1, **todos embarcan como Recluta con XP 0** (PRD §7.3).

## Derivación (no se persiste — PRD §5.5)

```
xp_total(candidato) = Σ logro.xp
rango(candidato)    = máx rango con xp_umbral ≤ xp_total
```

El cálculo derivado de `xp_total` y `rango` está en `src/lib/progresion.ts` (PRD §9.3),
leyendo `logro` vía el adaptador de estado + esta config. No se almacena ningún total ni
rango: se recalcula en cada consulta/render.
