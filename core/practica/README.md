# `/core/practica` — contrato de práctica

La **frontera agnóstica** entre el *motor de práctica* de un módulo y el *backend de
estado* del juego (PRD §3.1, §3.2, §9.7).

## El principio (decisión cerrada — §3.1)

Son **dos cosas distintas que no se acoplan**:

- **Motor de práctica/examen** — *dónde trabaja el alumno*. Lo aporta **cada módulo**
  según su tecnología (runner client-side, validador contra contenedor real, etc.).
  **No es parte del shell.** El examen se valida contra el **entorno real del módulo**.
- **Backend de estado** — *dónde vive el juego* (`candidato`, `logro`…). Es del shell.

El shell **no ejecuta práctica**. Lo único que cruza la frontera es el **resultado** de
un intento; si se supera, el shell lo certifica como una fila en el log `logro`.

## El contrato

Un módulo solo necesita: (1) ejecutar su reto como sepa, y (2) llamar a una función:

```ts
import { registrarIntento } from '@lib/practica';
import ilCatalog from '@modules/<x>/il.json';

// al resolver un ticket/examen en el motor del módulo:
const res = await registrarIntento({ il_id: 'IL1.2.N', superado: true }, ilCatalog.il);
// res.registrado === true  -> se escribió un logro (+XP)
// res.motivo === 'ya_certificado' | 'no_superado' | 'il_desconocido'
```

- La **XP** la toma del catálogo de IL del módulo (única fuente de verdad), no del motor.
- El log es **append-only**, pero el contrato **no recertifica** un IL ya logrado
  (no se dobla XP).
- A partir del `logro`, todo lo demás (XP, rango, credencial, mapa) se **deriva** solo.

## Implementación

- `src/lib/practica.ts` — el contrato (`registrarIntento`).
- `EstadoAdapter.registrarLogro()` (`src/lib/estado/`) — el INSERT real, con RLS:
  el alumno solo puede insertar logros propios.
- `src/pages/practica-demo.astro` — banco de pruebas que hace de motor de práctica
  *stand-in* para demostrar la frontera (no es un motor real; eso es del módulo).
