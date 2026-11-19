# Zona del visor: los 11 municipios con territorio en el Parque Nacional de los Picos de Europa
# (Asturias, Cantabria y León), del IGN (unidades administrativas INSPIRE).
# Salida: raw/provincia.gpkg (la zona: unión de los municipios; se llama así por compatibilidad con el visor de León),
#         raw/municipios.gpkg, raw/provincias.gpkg (las tres provincias recortadas al mapa) y raw/extension.txt
#         (X0 Y0 X1 Y1 del mapa en EPSG:25830: la zona más 3 km, redondeado al kilómetro).
suppressMessages({library(sf); library(dplyr)})
sf_use_s2(FALSE)
MUNICIPIOS <- c("33003" = "Amieva", "33008" = "Cabrales", "33012" = "Cangas de Onís", "33043" = "Onís",
                "33046" = "Peñamellera Alta", "33047" = "Peñamellera Baja",
                "39015" = "Camaleño", "39022" = "Cillorigo de Liébana", "39088" = "Tresviso",
                "24106" = "Oseja de Sajambre", "24116" = "Posada de Valdeón")
PROVINCIA <- c("33" = "Asturias", "39" = "Cantabria", "24" = "León")
au <- st_read("raw/au_units.gml", quiet = TRUE) %>% st_transform(25830)
au$code <- substr(au$nationalCode, 7, 11)
mun <- au %>% filter(nchar(nationalCode) == 11, code %in% names(MUNICIPIOS)) %>%
  transmute(code, nombre = text, tipo = "municipio", provincia = unname(PROVINCIA[substr(code, 1, 2)]))
stopifnot(nrow(mun) == length(MUNICIPIOS))
zona <- st_sf(code = "00000", nombre = "Picos de Europa", geometry = st_union(st_make_valid(mun)))
b <- st_bbox(st_buffer(zona, 3000))
ext <- unname(c(floor(b["xmin"] / 1000) * 1000, floor(b["ymin"] / 1000) * 1000, ceiling(b["xmax"] / 1000) * 1000, ceiling(b["ymax"] / 1000) * 1000))
caja <- st_as_sfc(st_bbox(c(xmin = ext[1], ymin = ext[2], xmax = ext[3], ymax = ext[4]), crs = st_crs(25830)))
prov <- au %>% filter(nchar(nationalCode) == 11, code == "00000", substr(nationalCode, 5, 6) %in% names(PROVINCIA)) %>%
  transmute(nombre = unname(PROVINCIA[substr(nationalCode, 5, 6)])) %>% st_intersection(caja)
st_write(zona, "raw/provincia.gpkg", delete_dsn = TRUE, quiet = TRUE)
st_write(mun, "raw/municipios.gpkg", delete_dsn = TRUE, quiet = TRUE)
st_write(prov, "raw/provincias.gpkg", delete_dsn = TRUE, quiet = TRUE)
writeLines(paste(ext, collapse = " "), "raw/extension.txt")
ll <- st_bbox(st_transform(caja, 4258))
writeLines(sprintf("%.4f,%.4f,%.4f,%.4f", ll["ymin"], ll["xmin"], ll["ymax"], ll["xmax"]), "raw/extension_latlon.txt")
cat("Zona:", round(as.numeric(st_area(zona)) / 1e6), "km²;", nrow(mun), "municipios\n")
cat("Mapa (EPSG:25830):", ext, sprintf("(%d × %d km)\n", (ext[3] - ext[1]) / 1000, (ext[4] - ext[2]) / 1000))
cat("Lat/lon:", readLines("raw/extension_latlon.txt"), "\n")
