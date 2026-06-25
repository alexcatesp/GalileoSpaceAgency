// Tipos compartidos del shell GASA. Espejo del modelo de datos del PRD §5.

export type Nivel = 'Suficiente' | 'Notable' | 'Excelente';

/** Config agnóstica de módulo (core/progresion/rango.json). */
export interface Rango {
  rango_id: string;
  nombre: string;
  xp_umbral: number;
  orden: number;
}

/** Fila del LOG append-only `logro` (PRD §5.2). */
export interface Logro {
  il_id: string;
  nivel: Nivel;
  xp: number;
  ts?: string;
}

/** Perfil seudónimo `candidato` (PRD §5.2). Sin PII. */
export interface Candidato {
  candidato_id: string;
  callsign: string;
  avatar_id: string;
  alta_ts?: string;
}

/** Objeto DERIVADO — no se persiste (PRD §5.5). */
export interface Credencial extends Candidato {
  xp_total: number;
  rango: Rango;
  progreso_siguiente_rango: { rango_id: string; nombre: string; xp_restante: number } | null;
  logros: Logro[];
}

/** Ítem de diagnóstico (transversal o específico). `respuesta_correcta` solo la usa el corrector. */
export interface ItemDiagnostico {
  id: string;
  categoria?: string;
  enunciado: string;
  opciones: string[];
  respuesta_correcta: number;
}

/** Criterio de Evaluación — hito del mapa (config por módulo, PRD §5.4). */
export interface CE {
  ce_id: string;
  ra_id: string;
  descripcion: string;
}

/** Indicador de Logro — unidad de evaluación y fuente de XP (config por módulo, PRD §5.4). */
export interface IL {
  il_id: string;
  ce_id: string;
  nivel: Nivel;
  xp: number;
  descripcion: string;
}

/** Nodo del mapa de misión (config por módulo, PRD §5.4). */
export interface NodoMapa {
  nodo_id: string;
  ce_id: string;
  titulo: string;
  depende_de: string | null;
  x: number;
  y: number;
}

/** Estado DERIVADO de un nodo del mapa (no se persiste, PRD §5.5). */
export type EstadoNodo = 'bloqueado' | 'disponible' | 'completado';

export const RE_CANDIDATO_ID = /^GASA-[0-9]{4}-[0-9]{3}$/;
