# `/data` — estado seudónimo versionado

Directorio **compartido, NO ramificado** (PRD §6) para cualquier estado seudónimo que se
decida versionar en git (p. ej. snapshots o seeds de configuración no sensible).

## Qué NO va aquí (requisito duro)

- **El fichero `mapeo`** (`candidato_id ↔ nombre_real ↔ grupo`) **JAMÁS** entra en git ni
  en el backend. Vive **offline en el disco del profesor** (PRD §4.1, §5.1). El
  `.gitignore` del repo incluye una red de seguridad para evitar subirlo por error.
- **Ningún PII.** El sistema nunca ve un nombre real.

El estado vivo del juego (`candidato`, `logro`, `diagnostico`) vive en **Supabase**, no
aquí. Este directorio es para datos que tenga sentido tener en git.

🚧 Vacío en el andamiaje v0.1.
