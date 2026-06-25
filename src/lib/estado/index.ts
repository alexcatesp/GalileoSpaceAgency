// Adaptador de ESTADO — la frontera entre la app y el backend (PRD §3.1: el
// backend de estado es fontanería interna, independiente del módulo). La app
// habla SIEMPRE contra esta interfaz; debajo hay dos implementaciones
// intercambiables:
//
//   · supabase  → backend real (Supabase Postgres + Auth + RLS).
//   · local     → datos en el navegador (localStorage), sin credenciales.
//
// El factory elige según haya o no credenciales PUBLIC_SUPABASE_* en el build,
// de modo que el MVP arranca y se demuestra sin un proyecto Supabase.

import type { Candidato, Logro } from '../tipos';

export interface Sesion {
  candidato_id: string;
}

export interface IngresoInput {
  callsign: string;
  avatar_id: string;
  score_transversal: number;
  score_especifico: number | null;
}

export interface EstadoAdapter {
  readonly modo: 'local' | 'supabase';
  /** Login seudónimo: candidato_id + código. Lanza si las credenciales no valen. */
  login(candidato_id: string, codigo: string): Promise<Sesion>;
  sesionActual(): Promise<Sesion | null>;
  logout(): Promise<void>;
  /** ¿El candidato ya completó el alta (tiene fila en `candidato`)? */
  yaDadoDeAlta(): Promise<boolean>;
  /** Alta del Día 1: crea `candidato` + `diagnostico` en una entrada (PRD §7.4). */
  completarIngreso(input: IngresoInput): Promise<void>;
  /** Fila `candidato` de la sesión (base de la credencial), o null si aún no hay alta. */
  getCandidato(): Promise<Candidato | null>;
  /** Logros del candidato de la sesión (para derivar XP/rango/credencial). */
  getLogros(): Promise<Logro[]>;
}

let _adapter: EstadoAdapter | null = null;

export async function getEstado(): Promise<EstadoAdapter> {
  if (_adapter) return _adapter;
  const url = import.meta.env.PUBLIC_SUPABASE_URL;
  const key = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;
  if (url && key) {
    const { SupabaseAdapter } = await import('./supabase');
    _adapter = new SupabaseAdapter(url, key);
  } else {
    const { LocalAdapter } = await import('./local');
    _adapter = new LocalAdapter();
  }
  return _adapter;
}
