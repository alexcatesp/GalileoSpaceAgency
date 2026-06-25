# `/core/mapa` — mapa de misión

Esquema y **render** del mapa de misión: el roadmap del módulo como árbol de hitos (CE).

El mapa es un **plano estático que se rellena**, NO un escenario navegable (PRD §2:
formato novela visual, no point-and-click). Los nodos se iluminan según los CE que
tienen IL logrados — estado **derivado** de `logro`, no persistido (PRD §5.5).

## Datos que consume

El render lee la config **por módulo** `nodo_mapa(nodo_id, ce_id, titulo, depende_de,
x, y)` desde `/modules/<x>/` (`depende_de` = prerequisito) y cruza con los `logro` del
candidato para decidir qué nodos están iluminados/bloqueados.

```
mapa = nodos iluminados según los CE con IL logrados
```

🚧 Pendiente de construir (PRD §9.6). Solo esqueleto en esta fase.
