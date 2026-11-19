# Picos en relieve

Mapa 3D interactivo de los **Picos de Europa** con su orografía real, pintado con un estilo ilustrado. Abarca los 11 municipios con territorio en el Parque Nacional, repartidos entre **Asturias, Cantabria y León**, y su entorno: unos 64 × 47 km con celdas de 30 m. Funciona en el navegador (HTML + [three.js](https://threejs.org/)), sin servidor de mapas ni teselas externas.

Es un proyecto hermano de [León en relieve](https://github.com/devlarosa/leon-en-relieve), del que hereda el visor.

**Ahora mismo**: relieve del MDT25, las ~1.300 cumbres con nombre del IGN (las principales siempre; el resto al acercarse), collados, horcadas y sierras, ríos, lagos, carreteras, los pueblos con su población, la población histórica desde 1900, la cubierta del suelo, el nivel del agua, el mirador (qué se ve desde cada punto) y el tutorial.

**Próximas fases**: espacios protegidos (Parque Nacional, Red Natura 2000, reservas de la biosfera); rutas y refugios; clima, geología e historia. Los scripts de esas capas vienen del proyecto de León y están pendientes de adaptar (`scripts/proteccion.R`, `scripts/geologia*.py`, `scripts/clima_aemet.py`, `scripts/historia.py`, `scripts/camino.py`, `scripts/incendios.R`, `scripts/rios_red*.py`, `scripts/lugares.py`). Sus pestañas están ocultas en el visor hasta tener datos (`data-ocultas` en `web/index.html`).

## La zona

| Provincia | Municipios |
|---|---|
| Asturias | Amieva, Cabrales, Cangas de Onís, Onís, Peñamellera Alta, Peñamellera Baja |
| Cantabria | Camaleño, Cillorigo de Liébana, Tresviso |
| León | Oseja de Sajambre, Posada de Valdeón |

La lista está en `R/03_admin.R` y en `scripts/zona.py`; la extensión del mapa (la zona más 3 km) se calcula sola y queda en `raw/extension.txt`.

## Fuentes

Todos los datos proceden de fuentes oficiales españolas o europeas:

| Capa | Fuente |
|---|---|
| Relieve | IGN · MDT25, WCS `servicios.idee.es/wcs-inspire/mdt` |
| Municipios y provincias | IGN · Unidades administrativas INSPIRE, WFS `www.ign.es/wfs-inspire/unidades-administrativas` |
| Ríos | IGN · Hidrografía INSPIRE, WFS `servicios.idee.es/wfs-inspire/hidrografia` |
| Lagos, carreteras | IGN · OGC API Features `api-features.idee.es` (`standingwater`, `roadlink`) |
| Pueblos, cumbres, sierras, valles, collados y puertos | IGN · Nomenclátor Geográfico Básico de España, WFS `www.ign.es/wfs-inspire/ngbe`; altitudes del MDT25 |
| Población | INE · Padrón municipal a 1 de enero de 2025 (tablas 2886, 2893 y 2877) y Nomenclátor (población de cada pueblo) |
| Densidad de población | INE · Censo 2021 en celdas de 1 km² de la rejilla europea |
| Población histórica | INE · Alteraciones de los municipios en los Censos de Población desde 1842 |
| Cubierta del suelo y bosques | Copernicus · CLC+ Backbone 2021 (Agencia Europea de Medio Ambiente) |

## Reconstruir los datos

Los datos no están en el repositorio: se descargan de los servicios oficiales y se procesan. Hace falta R con `sf`, `terra`, `dplyr` y `jsonlite`, y Python 3.

```bash
scripts/descargar_datos.sh          # IGN e INE -> raw/ (incluye R/03_admin.R: zona y extensión del mapa)
Rscript R/10_preparar_web.R         # web/data/relieve.png y web/data/zona.json
Rscript R/11_rejilla_poblacion.R    # web/data/poblacion.png (densidad, Censo 2021)
Rscript R/12_cobertura_copernicus.R # web/data/cobertura.png (Copernicus CLC+)
Rscript scripts/cumbres.R           # web/data/cumbres.json (todas las cumbres con nombre)
./abrir_visor.sh                    # abre el visor en http://127.0.0.1:8801
```

`servidor/servidor.py` lo sirve como aplicación instalable en el móvil (puerto 8801; ver `servidor/picos3d-visor.service`), con usuario y contraseña opcionales y límites de carga. `scripts/publicar_pages.py` prepara una versión estática para Cloudflare Pages u otro alojamiento.

## Licencias

El código es MIT (`LICENSE`). Los datos son de sus autores y se reutilizan citando la fuente: IGN (CC BY 4.0), INE, Copernicus/AEMA (reutilización libre con atribución).
