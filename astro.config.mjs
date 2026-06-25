// @ts-check
import { defineConfig } from 'astro/config';

// Frontend estático de GASA (novela visual + mapa + carnet + manuales).
// Destino de despliegue: GitHub Pages.
//
// `site` y `base` se ajustan al publicar. Para GitHub Pages de proyecto,
// `base` debe ser el nombre del repo. Se dejan parametrizados por variables
// de entorno para no acoplar el build a una URL concreta.
export default defineConfig({
  site: process.env.SITE_URL || 'https://alexcatesp.github.io',
  base: process.env.BASE_PATH || '/GalileoSpaceAgency',
  output: 'static',
  trailingSlash: 'ignore',
});
