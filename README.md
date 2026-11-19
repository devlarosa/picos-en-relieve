# Picos en relieve → integrado en «León en relieve»

Este repositorio está **archivado**. El visor de los Picos de Europa vive ahora dentro de
[devlarosa/leon-en-relieve](https://github.com/devlarosa/leon-en-relieve), que sirve varias zonas con el mismo código:

- `index.html?zona=picos` (o el selector «Mapa» del panel) abre los Picos de Europa
- la ficha de la zona está en `web/zonas.json` y sus datos se generan con `ZONA=picos scripts/descargar_datos.sh`
  y `ZONA=picos Rscript R/10_preparar_web.R` (ver el README de aquel repositorio)
