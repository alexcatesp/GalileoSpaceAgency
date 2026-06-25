// Estado DERIVADO del mapa de misión (PRD §5.5, §9.6): "mapa = nodos iluminados
// según los CE con IL logrados". No se persiste; se calcula de `logro` + config.

import type { IL, NodoMapa, Logro, EstadoNodo } from './tipos';

export interface NodoConEstado extends NodoMapa {
  estado: EstadoNodo;
}

/**
 * CE cubiertos: un CE se considera cubierto cuando tiene al menos un IL logrado
 * (cualquier nivel). Es lo que ilumina su nodo en el mapa.
 */
export function cesCubiertos(logros: Logro[], catalogoIL: IL[]): Set<string> {
  const ilLogrados = new Set(logros.map((l) => l.il_id));
  const ces = new Set<string>();
  for (const il of catalogoIL) if (ilLogrados.has(il.il_id)) ces.add(il.ce_id);
  return ces;
}

/**
 * Calcula el estado de cada nodo:
 *  - completado: su CE está cubierto.
 *  - disponible: no completado, pero su prerequisito está cubierto (o es raíz).
 *  - bloqueado:  su prerequisito aún no está cubierto.
 */
export function estadoDelMapa(nodos: NodoMapa[], logros: Logro[], catalogoIL: IL[]): NodoConEstado[] {
  const cubiertos = cesCubiertos(logros, catalogoIL);
  const porId = new Map(nodos.map((n) => [n.nodo_id, n]));

  return nodos.map((n) => {
    let estado: EstadoNodo;
    if (cubiertos.has(n.ce_id)) {
      estado = 'completado';
    } else {
      const prereq = n.depende_de ? porId.get(n.depende_de) : null;
      const desbloqueado = !n.depende_de || (prereq ? cubiertos.has(prereq.ce_id) : false);
      estado = desbloqueado ? 'disponible' : 'bloqueado';
    }
    return { ...n, estado };
  });
}
