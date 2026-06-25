# `/modules/_template` — plantilla de instancia de módulo

Copia este directorio a `/modules/<nombre-del-modulo>` para crear una nueva instancia.
Un módulo **consume `/core`** y solo aporta su **parametrización** (PRD §6).

## Qué aporta un módulo

1. **Parámetros narrativos** — `modulo.json`: `(año, planeta, módulo)` + NPCs/narrativa
   de la temporada. La narrativa concreta es contenido, no código.
2. **Config de evaluación** — el mismo esquema del shell con contenido propio (PRD §5.4):
   - `ra.json` — Resultados de Aprendizaje (objetivos de misión).
   - `ce.json` — Criterios de Evaluación (hitos del mapa).
   - `il.json` — Indicadores de Logro (entregables/certificaciones): **la unidad de
     evaluación y la fuente de XP**. Graduados en `Suficiente / Notable / Excelente`,
     con descripción concreta y observable + XP por nivel. **Los IL reales los aporta el
     profesor.**
   - `nodo_mapa.json` — nodos del mapa (`depende_de` = prerequisito; `x`, `y` = layout).
3. **Bloque específico del diagnóstico** — `diagnostico_especifico.json`: ítems de
   conocimiento previo del dominio para la ficha de ingreso (PRD §7.3).
4. **Motor de práctica/examen** — lo provee el módulo según su tecnología; **no es parte
   del shell**. Ejecución client-side cuando sea posible; examen validado contra el
   entorno real del módulo (PRD §3.1). El shell solo registra el intento/resultado.

## Relación con el modelo de datos

```
ra  1───* ce  1───* il        (il.xp alimenta logro.xp al certificarse)
ce  1───* nodo_mapa           (los nodos del mapa cuelgan de los CE)
```

Los ficheros incluidos son **esqueletos con un ejemplo mínimo** para fijar el formato.
Sustitúyelos por el contenido real al instanciar un módulo.
