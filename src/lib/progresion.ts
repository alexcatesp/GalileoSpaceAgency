// Progresión DERIVADA (PRD §5.5): xp_total, rango y hueco al siguiente rango se
// CALCULAN a partir de `logro` + config de `rango`. Nada de esto se persiste.

import type { Rango, Logro, Candidato, Credencial } from './tipos';

export function xpTotal(logros: Logro[]): number {
  return logros.reduce((s, l) => s + (l.xp || 0), 0);
}

function porUmbralAsc(rangos: Rango[]): Rango[] {
  return [...rangos].sort((a, b) => a.xp_umbral - b.xp_umbral);
}

/** rango(candidato) = máx rango con xp_umbral <= xp_total (PRD §5.5). */
export function rangoDesdeXp(xp: number, rangos: Rango[]): Rango {
  const ordenados = porUmbralAsc(rangos);
  let actual = ordenados[0];
  for (const r of ordenados) if (xp >= r.xp_umbral) actual = r;
  return actual;
}

export function progresoSiguienteRango(
  xp: number,
  rangos: Rango[],
): { rango_id: string; nombre: string; xp_restante: number } | null {
  const siguiente = porUmbralAsc(rangos).find((r) => r.xp_umbral > xp);
  return siguiente
    ? { rango_id: siguiente.rango_id, nombre: siguiente.nombre, xp_restante: siguiente.xp_umbral - xp }
    : null;
}

/** Compone la credencial (objeto derivado) a partir del candidato + sus logros. */
export function credencialDerivada(candidato: Candidato, logros: Logro[], rangos: Rango[]): Credencial {
  const xp = xpTotal(logros);
  return {
    ...candidato,
    xp_total: xp,
    rango: rangoDesdeXp(xp, rangos),
    progreso_siguiente_rango: progresoSiguienteRango(xp, rangos),
    logros,
  };
}
