// CONTRATO DE PRÁCTICA (PRD §3.1, §3.2, §9.7).
//
// La frontera agnóstica entre el MOTOR DE PRÁCTICA de un módulo (donde el alumno
// trabaja; lo aporta cada módulo según su tecnología) y el BACKEND DE ESTADO
// (donde vive el juego). El shell NO ejecuta práctica: solo recibe el resultado
// de un intento y, si procede, lo certifica como una fila en `logro`.
//
// Un módulo solo necesita: (1) ejecutar su reto como sepa, y (2) llamar a
// `registrarIntento({ il_id, superado }, catalogoIL)`. Nada más cruza la frontera.

import type { IL, Logro } from './tipos';
import { getEstado } from './estado/index';

/** Lo que el motor de práctica de un módulo reporta al resolver un ticket/examen. */
export interface ResultadoIntento {
  /** Qué Indicador de Logro se evaluaba (debe existir en el catálogo del módulo). */
  il_id: string;
  /** Si false, el intento no certifica nada. */
  superado: boolean;
}

export type MotivoNoRegistro = 'no_superado' | 'il_desconocido' | 'ya_certificado';

export interface RegistroLogro {
  registrado: boolean;
  motivo?: MotivoNoRegistro;
  logro?: Logro;
}

/**
 * Punto único del contrato. Valida el `il_id` contra el catálogo del módulo,
 * toma la XP de la config (única fuente de verdad, no del módulo) y escribe el
 * logro si el intento se superó y no estaba ya certificado.
 *
 * @param resultado   lo que reporta el motor de práctica del módulo
 * @param catalogoIL  los IL del módulo (modules/<x>/il.json) — fuente de la XP
 */
export async function registrarIntento(resultado: ResultadoIntento, catalogoIL: IL[]): Promise<RegistroLogro> {
  if (!resultado.superado) return { registrado: false, motivo: 'no_superado' };

  const il = catalogoIL.find((x) => x.il_id === resultado.il_id);
  if (!il) return { registrado: false, motivo: 'il_desconocido' };

  const estado = await getEstado();
  const previos = await estado.getLogros();
  // El log es append-only, pero no se recertifica el mismo IL (no doblar XP).
  if (previos.some((l) => l.il_id === il.il_id)) return { registrado: false, motivo: 'ya_certificado' };

  const logro = await estado.registrarLogro({ il_id: il.il_id, nivel: il.nivel, xp: il.xp });
  return { registrado: true, logro };
}
