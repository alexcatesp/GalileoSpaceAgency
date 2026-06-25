// Implementación LOCAL del adaptador de estado: todo en localStorage del
// navegador. Sirve para desarrollar y demostrar el Día 1 SIN un proyecto
// Supabase. NO es seguro ni multiusuario — es un sustituto fiel a la interfaz.
//
// Nota: aquí no hay códigos reales (los reparte el profesor en la provisión);
// en modo local aceptamos cualquier candidato_id con formato válido + un código
// no vacío, para poder probar el flujo.

import type { Candidato, Logro } from '../tipos';
import { RE_CANDIDATO_ID } from '../tipos';
import type { EstadoAdapter, IngresoInput, Sesion } from './index';

const K_SESION = 'gasa:sesion';
const K_CANDIDATO = (id: string) => `gasa:candidato:${id}`;
const K_DIAG = (id: string) => `gasa:diagnostico:${id}`;
const K_LOGROS = (id: string) => `gasa:logros:${id}`;

export class LocalAdapter implements EstadoAdapter {
  readonly modo = 'local' as const;

  async login(candidato_id: string, codigo: string): Promise<Sesion> {
    const id = candidato_id.trim().toUpperCase();
    if (!RE_CANDIDATO_ID.test(id)) {
      throw new Error('El candidato_id debe tener el formato GASA-2627-NNN.');
    }
    if (!codigo || codigo.trim().length < 4) {
      throw new Error('Introduce tu código de acceso.');
    }
    const sesion: Sesion = { candidato_id: id };
    localStorage.setItem(K_SESION, JSON.stringify(sesion));
    return sesion;
  }

  async sesionActual(): Promise<Sesion | null> {
    const raw = localStorage.getItem(K_SESION);
    return raw ? (JSON.parse(raw) as Sesion) : null;
  }

  async logout(): Promise<void> {
    localStorage.removeItem(K_SESION);
  }

  private async idSesion(): Promise<string> {
    const s = await this.sesionActual();
    if (!s) throw new Error('No hay sesión activa.');
    return s.candidato_id;
  }

  async yaDadoDeAlta(): Promise<boolean> {
    const id = await this.idSesion();
    return localStorage.getItem(K_CANDIDATO(id)) !== null;
  }

  async completarIngreso(input: IngresoInput): Promise<void> {
    const id = await this.idSesion();
    if (localStorage.getItem(K_CANDIDATO(id))) {
      throw new Error('Este candidato ya está dado de alta.');
    }
    const candidato: Candidato = {
      candidato_id: id,
      callsign: input.callsign,
      avatar_id: input.avatar_id,
      alta_ts: new Date().toISOString(),
    };
    localStorage.setItem(K_CANDIDATO(id), JSON.stringify(candidato));
    // diagnóstico: privado del profesor; se guarda pero la app del alumno no lo lee.
    localStorage.setItem(
      K_DIAG(id),
      JSON.stringify({
        candidato_id: id,
        score_transversal: input.score_transversal,
        score_especifico: input.score_especifico,
      }),
    );
    // todos embarcan como Recluta con XP 0: el log de logros nace vacío.
    if (!localStorage.getItem(K_LOGROS(id))) localStorage.setItem(K_LOGROS(id), '[]');
  }

  async getCandidato(): Promise<Candidato | null> {
    const id = await this.idSesion();
    const raw = localStorage.getItem(K_CANDIDATO(id));
    return raw ? (JSON.parse(raw) as Candidato) : null;
  }

  async getLogros(): Promise<Logro[]> {
    const id = await this.idSesion();
    const raw = localStorage.getItem(K_LOGROS(id));
    return raw ? (JSON.parse(raw) as Logro[]) : [];
  }

  async registrarLogro(logro: Pick<Logro, 'il_id' | 'nivel' | 'xp'>): Promise<Logro> {
    const id = await this.idSesion();
    const fila: Logro = { ...logro, ts: new Date().toISOString() };
    const logros = await this.getLogros();
    logros.push(fila); // append-only
    localStorage.setItem(K_LOGROS(id), JSON.stringify(logros));
    return fila;
  }
}
