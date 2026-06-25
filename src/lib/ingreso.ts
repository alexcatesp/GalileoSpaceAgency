// Corrección de la ficha de ingreso. REGLA DURA (PRD §7.3): el diagnóstico es
// privado del profesor y SABOR para el alumno; NO es XP ni ranking. Todos
// embarcan como Recluta con XP 0 sea cual sea el resultado.

import type { ItemDiagnostico } from './tipos';

export interface Respuesta {
  id: string;
  eleccion: number; // índice de la opción elegida; -1 = sin responder
}

/**
 * Puntúa un bloque de ítems. Devuelve el porcentaje de aciertos (0–100).
 * Genérico sobre cualquier ítem con `id` + `respuesta_correcta`.
 */
export function puntuarBloque(
  items: Pick<ItemDiagnostico, 'id' | 'respuesta_correcta'>[],
  respuestas: Respuesta[],
): number {
  if (items.length === 0) return 0;
  const elegidoPorId = new Map(respuestas.map((r) => [r.id, r.eleccion]));
  let aciertos = 0;
  for (const item of items) {
    if (elegidoPorId.get(item.id) === item.respuesta_correcta) aciertos++;
  }
  return Math.round((100 * aciertos) / items.length);
}
