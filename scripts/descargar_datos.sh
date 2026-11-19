#!/usr/bin/env bash
# Descarga los datos de partida en raw/ desde los servicios oficiales (IGN e INE).
# Se puede relanzar: salta lo que ya está descargado y completo.
# Los servidores del IGN fallan a menudo (502, respuestas cortadas): el script reintenta.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p raw/{mdt25,rios,ngbe,carreteras,aguas_api,historico,rejilla,nomenclator}
UA="Mozilla/5.0 (compatible; picos3d-datos/1.0)"

completo() {  # fichero GML/XML que termina bien
  [ -s "$1" ] && tail -c 64 "$1" | grep -q "FeatureCollection>"
}
bajar() {     # bajar URL fichero [comprobación]
  local url="$1" out="$2" check="${3:-}"
  for i in 1 2 3 4 5 6; do
    if curl -sfL -m 600 -A "$UA" "$url" -o "$out" && [ -s "$out" ]; then
      if [ -z "$check" ] || $check "$out"; then echo "  ok $out"; return 0; fi
    fi
    echo "  reintento $i: $out"; sleep $((i * 6))
  done
  echo "  FALLO: $out" >&2; return 1
}
wfs_filtro() {  # servicio tipo filtro_xml salida
  local url="$1" tipo="$2" filtro="$3" out="$4"
  completo "$out" && { echo "  ya está $out"; return 0; }
  for i in 1 2 3 4 5 6; do
    curl -s -m 600 -A "$UA" -G "$url" --data-urlencode "service=WFS" --data-urlencode "version=2.0.0" \
      --data-urlencode "request=GetFeature" --data-urlencode "typeNames=$tipo" --data-urlencode "count=20000" \
      --data-urlencode "filter=$filtro" -o "$out" && completo "$out" && { echo "  ok $out"; return 0; }
    echo "  reintento $i: $out"; sleep $((i * 6))
  done
  echo "  FALLO: $out" >&2; return 1
}

echo "1/8 Límites administrativos (IGN, unidades administrativas INSPIRE) y zona del mapa"
completo raw/au_units.gml || bajar "https://www.ign.es/wfs-inspire/unidades-administrativas?service=WFS&version=2.0.0&request=GetFeature&typeNames=au:AdministrativeUnit&bbox=42.95,-5.40,43.45,-4.40,urn:ogc:def:crs:EPSG::4258&count=5000" raw/au_units.gml completo
[ -s raw/extension.txt ] || Rscript R/03_admin.R || exit 1
read X0 Y0 X1 Y1 < raw/extension.txt
IFS=, read LA0 LO0 LA1 LO1 < raw/extension_latlon.txt
ENV="<gml:Envelope srsName=\"urn:ogc:def:crs:EPSG::4258\"><gml:lowerCorner>$LA0 $LO0</gml:lowerCorner><gml:upperCorner>$LA1 $LO1</gml:upperCorner></gml:Envelope>"

echo "2/8 Relieve: MDT25 del IGN (WCS), en mosaicos de 32 km"
for ((x = X0; x < X1; x += 32000)); do for ((y = Y0; y < Y1; y += 32000)); do
  f=raw/mdt25/t_${x}_${y}.tif; [ -s "$f" ] && continue
  bajar "https://servicios.idee.es/wcs-inspire/mdt?service=WCS&version=2.0.1&request=GetCoverage&CoverageId=Elevacion25830_25&subset=x($x,$((x + 32000 > X1 ? X1 : x + 32000)))&subset=y($y,$((y + 32000 > Y1 ? Y1 : y + 32000)))&format=image/tiff" "$f"
done; done

echo "3/8 Ríos con nombre (IGN, hidrografía INSPIRE)"
FRIOS="<fes:Filter xmlns:fes=\"http://www.opengis.net/fes/2.0\" xmlns:hy-p=\"http://inspire.ec.europa.eu/schemas/hy-p/4.0\" xmlns:gn=\"http://inspire.ec.europa.eu/schemas/gn/4.0\" xmlns:gml=\"http://www.opengis.net/gml/3.2\"><fes:And><fes:BBOX><fes:ValueReference>hy-p:geometry</fes:ValueReference>$ENV</fes:BBOX><fes:PropertyIsLike wildCard=\"*\" singleChar=\".\" escapeChar=\"!\"><fes:ValueReference>hy-p:geographicalName/gn:GeographicalName/gn:spelling/gn:SpellingOfName/gn:text</fes:ValueReference><fes:Literal>Río *</fes:Literal></fes:PropertyIsLike></fes:And></fes:Filter>"
wfs_filtro "https://servicios.idee.es/wfs-inspire/hidrografia" "hy-p:Watercourse" "$FRIOS" raw/rios/q_0.gml

echo "4/8 Nomenclátor Geográfico Básico (IGN): poblaciones y orografía"
for T in "Capital de provincia" "Capital de municipio" "Entidad singular" "Núcleos de población" "Capital de EATIM" "Entidad menor de población" "Montaña" "Alineación montañosa" "Depresión" "Paso de montaña" "Comarca geográfica"; do
  F="<fes:Filter xmlns:fes=\"http://www.opengis.net/fes/2.0\" xmlns:gn=\"http://inspire.ec.europa.eu/schemas/gn/4.0\" xmlns:gmd=\"http://www.isotc211.org/2005/gmd\" xmlns:gml=\"http://www.opengis.net/gml/3.2\"><fes:And><fes:BBOX><fes:ValueReference>gn:geometry</fes:ValueReference>$ENV</fes:BBOX><fes:PropertyIsEqualTo><fes:ValueReference>gn:localType/gmd:LocalisedCharacterString</fes:ValueReference><fes:Literal>$T</fes:Literal></fes:PropertyIsEqualTo></fes:And></fes:Filter>"
  wfs_filtro "https://www.ign.es/wfs-inspire/ngbe" "gn:NamedPlace" "$F" "raw/ngbe/$(echo "$T" | tr ' ' '_').gml"
done

echo "5/8 Lagos y embalses, carreteras (IGN, OGC API Features de la IDEE)"
[ -s raw/aguas_api/standingwater.geojson ] || python3 -I scripts/fetch_ogcapi.py standingwater raw/aguas_api/standingwater.geojson
for c in mainRoad firstClass secondClass thirdClass; do
  [ -s raw/carreteras/$c.geojson ] || python3 -I scripts/fetch_ogcapi.py roadlink raw/carreteras/$c.geojson functionalclass=$c
done

echo "6/8 Población (INE): Padrón municipal y Nomenclátor de cada pueblo"
[ -s raw/poblacion_ine_2025.csv ] || python3 -I scripts/ine_poblacion.py raw/poblacion_ine_2025.csv
[ -s raw/nomenclator/entidades_ine.csv ] || python3 -I scripts/ine_nomenclator.py 2025 raw/nomenclator/entidades_ine.csv

echo "7/8 Población del Censo 2021 en celdas de 1 km² (INE, rejilla europea)"
[ -s raw/rejilla/Poblacion_Rejilla_Europea.csv ] || bajar "https://www.ine.es/censos2021/Poblacion_Rejilla_Europea.csv" raw/rejilla/Poblacion_Rejilla_Europea.csv

echo "8/8 Población histórica (INE, censos desde 1900)"
[ -s raw/historico/censos.json ] || python3 -I scripts/ine_censos.py raw/poblacion_ine_2025.csv raw/historico/censos.json

echo "Hecho. Siguiente paso: Rscript R/10_preparar_web.R && Rscript R/11_rejilla_poblacion.R && Rscript R/12_cobertura_copernicus.R"
