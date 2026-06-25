/// <reference path="../.astro/types.d.ts" />

interface ImportMetaEnv {
  /** URL del proyecto Supabase. Si falta, la app usa el adaptador local. */
  readonly PUBLIC_SUPABASE_URL?: string;
  /** Clave anónima (publishable) de Supabase — segura en cliente por RLS. */
  readonly PUBLIC_SUPABASE_ANON_KEY?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
