# `/core/carnet` — perfil / credencial

Esquema del perfil del candidato y **plantilla de render** de la credencial (el "carnet"
GASA: identidad persistente del alumno).

La credencial es un objeto **derivado** (PRD §5.5): se compone de los datos de
`candidato` (callsign, avatar, alta) + sus `logro` (huecos de certificación rellenos) +
el rango derivado de la XP. **No se persiste** una credencial; se renderiza al vuelo.

## Contenido (andamiaje v0.1)

- Esquema del perfil/credencial y la plantilla de render se construyen en la fase de
  Galería de avatares + render de credencial (PRD §9.5).
- El avatar es una **referencia a un asset de galería cerrada** (`avatar_id`), nunca una
  imagen personal subida (PRD §2 no-objetivos, §7.4).

🚧 Pendiente de construir. Solo esqueleto en esta fase.
