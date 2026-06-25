// Implementación SUPABASE del adaptador de estado. Login seudónimo: el
// candidato_id se traduce a un email sintético no enrutable (el mismo que fija
// la provisión) y el código es la contraseña. El candidato_id "de verdad" se
// lee del claim app_metadata.candidato_id del JWT, no de lo que teclee el
// usuario. RLS hace el resto: cada uno ve lo suyo; `diagnostico` solo el profesor.

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { Candidato, Logro } from '../tipos';
import { RE_CANDIDATO_ID } from '../tipos';
import type { EstadoAdapter, IngresoInput, Sesion } from './index';

function emailSintetico(candidato_id: string): string {
  return `${candidato_id.toLowerCase()}@candidatos.gasa.local`;
}

export class SupabaseAdapter implements EstadoAdapter {
  readonly modo = 'supabase' as const;
  private sb: SupabaseClient;

  constructor(url: string, anonKey: string) {
    this.sb = createClient(url, anonKey);
  }

  private async candidatoIdDeSesion(): Promise<string | null> {
    const { data } = await this.sb.auth.getUser();
    const claim = data.user?.app_metadata?.candidato_id;
    return typeof claim === 'string' ? claim : null;
  }

  async login(candidato_id: string, codigo: string): Promise<Sesion> {
    const id = candidato_id.trim().toUpperCase();
    if (!RE_CANDIDATO_ID.test(id)) {
      throw new Error('El candidato_id debe tener el formato GASA-2627-NNN.');
    }
    const { error } = await this.sb.auth.signInWithPassword({
      email: emailSintetico(id),
      password: codigo.trim(),
    });
    if (error) throw new Error('candidato_id o código incorrectos.');
    const real = (await this.candidatoIdDeSesion()) ?? id;
    return { candidato_id: real };
  }

  async sesionActual(): Promise<Sesion | null> {
    const id = await this.candidatoIdDeSesion();
    return id ? { candidato_id: id } : null;
  }

  async logout(): Promise<void> {
    await this.sb.auth.signOut();
  }

  async yaDadoDeAlta(): Promise<boolean> {
    return (await this.getCandidato()) !== null;
  }

  async completarIngreso(input: IngresoInput): Promise<void> {
    const { data: u } = await this.sb.auth.getUser();
    const user = u.user;
    const candidato_id = (user?.app_metadata?.candidato_id as string) ?? null;
    if (!user || !candidato_id) throw new Error('No hay sesión válida.');

    // Una entrada -> crea `candidato` + `diagnostico` (PRD §7.4).
    const { error: e1 } = await this.sb.from('candidato').insert({
      candidato_id,
      auth_user_id: user.id,
      callsign: input.callsign,
      avatar_id: input.avatar_id,
    });
    if (e1) throw new Error(`No se pudo crear el perfil: ${e1.message}`);

    // diagnostico: el alumno solo INSERTA (no puede leerlo); privado del profesor.
    const { error: e2 } = await this.sb.from('diagnostico').insert({
      candidato_id,
      score_transversal: input.score_transversal,
      score_especifico: input.score_especifico,
    });
    if (e2) throw new Error(`No se pudo guardar el diagnóstico: ${e2.message}`);
  }

  async getCandidato(): Promise<Candidato | null> {
    const { data } = await this.sb
      .from('candidato')
      .select('candidato_id, callsign, avatar_id, alta_ts')
      .maybeSingle();
    return (data as Candidato) ?? null;
  }

  async getLogros(): Promise<Logro[]> {
    const { data } = await this.sb
      .from('logro')
      .select('il_id, nivel, xp, ts')
      .order('ts', { ascending: true });
    return (data as Logro[]) ?? [];
  }

  async registrarLogro(logro: Pick<Logro, 'il_id' | 'nivel' | 'xp'>): Promise<Logro> {
    const candidato_id = await this.candidatoIdDeSesion();
    if (!candidato_id) throw new Error('No hay sesión válida.');
    // INSERT en el log append-only; RLS exige candidato_id = el del JWT.
    const { data, error } = await this.sb
      .from('logro')
      .insert({ candidato_id, il_id: logro.il_id, nivel: logro.nivel, xp: logro.xp })
      .select('il_id, nivel, xp, ts')
      .single();
    if (error) throw new Error(`No se pudo registrar el logro: ${error.message}`);
    return data as Logro;
  }
}
