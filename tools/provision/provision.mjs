#!/usr/bin/env node
// ===========================================================================
// GASA — Provisión de candidatos (flujo del PROFESOR, fuera del juego)
// ---------------------------------------------------------------------------
// Lee la orla (CSV con nombre_real + grupo) y, por cada alumno:
//   1. genera un `candidato_id` opaco  GASA-<cohorte>-NNN   (PRD §4.3)
//   2. genera un `codigo` de acceso alfanumérico corto       (PRD §4.3)
//   3. crea el usuario en Supabase Auth con EMAIL SINTÉTICO no enrutable y el
//      claim app_metadata.candidato_id  (login = candidato_id + codigo, sin PII)
//   4. escribe el fichero `mapeo` OFFLINE (candidato_id ↔ nombre_real ↔ grupo)
//   5. escribe el `reparto` (candidato_id + codigo) para entregar a cada alumno
//
// REQUISITO DURO (PRD §4, §5.1): el `mapeo` es el ÚNICO artefacto sensible y
// JAMÁS entra en git ni en el backend. Se escribe fuera del repo (o a una ruta
// gitignored). El backend solo ve callsigns y resultados, nunca personas.
//
// Uso:
//   node tools/provision/provision.mjs --orla <orla.csv> [opciones]
//
//   --orla <ruta>        CSV de entrada. Cabeceras: nombre_real,grupo
//   --cohorte <NNNN>     Cohorte (def. 2627). Forma el candidato_id.
//   --inicio <N>         Primer secuencial (def. 1).
//   --out <dir>          Dónde escribir mapeo/reparto (def. ./.provision — gitignored)
//   --dry-run            NO toca Supabase: solo genera IDs/códigos/mapeo/reparto.
//
// Credenciales (NO en --dry-run): variables de entorno o tools/provision/.env
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY      (service_role = rol profesor)
// ===========================================================================

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomInt } from 'node:crypto';

const __dirname = dirname(fileURLToPath(import.meta.url));

// --- mini cargador de .env (sin dependencias) ------------------------------
function loadEnv(path) {
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !(m[1] in process.env)) {
      process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
  }
}
loadEnv(join(__dirname, '.env'));

// --- args ------------------------------------------------------------------
function arg(name, def = undefined) {
  const i = process.argv.indexOf(`--${name}`);
  if (i === -1) return def;
  const v = process.argv[i + 1];
  return v && !v.startsWith('--') ? v : true;
}
const ORLA = arg('orla');
const COHORTE = String(arg('cohorte', '2627'));
const INICIO = parseInt(arg('inicio', '1'), 10);
const OUT = resolve(String(arg('out', join(process.cwd(), '.provision'))));
const DRY = Boolean(arg('dry-run', false));

if (!ORLA) {
  console.error('Falta --orla <orla.csv>. Ver cabecera del script para el uso.');
  process.exit(1);
}

// --- utilidades ------------------------------------------------------------
// Alfabeto sin caracteres ambiguos (0/O, 1/I/L) para códigos legibles.
const ALFABETO = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
function generarCodigo(n = 6) {
  let s = '';
  for (let i = 0; i < n; i++) s += ALFABETO[randomInt(ALFABETO.length)];
  return s;
}
function candidatoId(seq) {
  return `GASA-${COHORTE}-${String(seq).padStart(3, '0')}`;
}
function emailSintetico(id) {
  // No enrutable, no es PII; solo el vehículo que pide Supabase Auth.
  return `${id.toLowerCase()}@candidatos.gasa.local`;
}
function parseCSV(texto) {
  const lineas = texto.split(/\r?\n/).filter((l) => l.trim() !== '');
  const cab = lineas.shift().split(',').map((s) => s.trim().toLowerCase());
  const iNombre = cab.indexOf('nombre_real');
  const iGrupo = cab.indexOf('grupo');
  if (iNombre === -1) throw new Error('La orla debe tener una columna "nombre_real".');
  return lineas.map((l) => {
    const c = l.split(',');
    return { nombre_real: (c[iNombre] || '').trim(), grupo: (iGrupo > -1 ? c[iGrupo] || '' : '').trim() };
  });
}
function aCSV(filas, columnas) {
  const esc = (v) => (/[",\n]/.test(String(v)) ? `"${String(v).replace(/"/g, '""')}"` : String(v));
  return [columnas.join(','), ...filas.map((f) => columnas.map((c) => esc(f[c] ?? '')).join(','))].join('\n') + '\n';
}

// --- 1) leer orla y generar identidades ------------------------------------
const alumnos = parseCSV(readFileSync(resolve(ORLA), 'utf8'));
if (alumnos.length === 0) {
  console.error('La orla no contiene filas.');
  process.exit(1);
}

const registros = alumnos.map((a, i) => {
  const id = candidatoId(INICIO + i);
  return { candidato_id: id, codigo: generarCodigo(), email: emailSintetico(id), ...a };
});

// --- 2) crear usuarios en Supabase Auth (salvo --dry-run) ------------------
if (!DRY) {
  const URL = process.env.SUPABASE_URL;
  const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!URL || !KEY) {
    console.error('Faltan SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY (env o tools/provision/.env).');
    console.error('Usa --dry-run para generar IDs/códigos/mapeo sin tocar Supabase.');
    process.exit(1);
  }
  const { createClient } = await import('@supabase/supabase-js');
  const admin = createClient(URL, KEY, { auth: { autoRefreshToken: false, persistSession: false } });

  for (const r of registros) {
    const { error } = await admin.auth.admin.createUser({
      email: r.email,
      password: r.codigo,
      email_confirm: true,
      app_metadata: { candidato_id: r.candidato_id }, // claim no falsificable por el alumno
    });
    if (error) {
      console.error(`  ✗ ${r.candidato_id}: ${error.message}`);
    } else {
      console.log(`  ✓ ${r.candidato_id}  (usuario auth creado)`);
    }
  }
} else {
  console.log(`[dry-run] ${registros.length} identidades generadas (no se ha tocado Supabase).`);
}

// --- 3) escribir mapeo (SENSIBLE, offline) y reparto -----------------------
mkdirSync(OUT, { recursive: true });

const mapeoPath = join(OUT, `mapeo_${COHORTE}.csv`);   // candidato_id ↔ nombre_real ↔ grupo
const repartoPath = join(OUT, `reparto_${COHORTE}.csv`); // candidato_id + codigo (para entregar)

writeFileSync(mapeoPath, aCSV(registros, ['candidato_id', 'nombre_real', 'grupo']), 'utf8');
writeFileSync(repartoPath, aCSV(registros, ['candidato_id', 'codigo', 'grupo']), 'utf8');

console.log('');
console.log('Listo. Artefactos generados:');
console.log(`  · MAPEO (SENSIBLE, NO subir a git/backend): ${mapeoPath}`);
console.log(`  · REPARTO (entregar a cada alumno su fila): ${repartoPath}`);
console.log('');
console.log('⚠  El mapeo es el único cruce a identidad real. Guárdalo offline y bórralo del repo si lo copiaste por error.');
