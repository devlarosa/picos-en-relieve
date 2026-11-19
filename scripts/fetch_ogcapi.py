"""Descarga paginada desde la OGC API Features de la IDEE (IGN). Uso: fetch_ogcapi.py coleccion salida.geojson [filtro=valor ...]"""
import json, sys, time, urllib.request, urllib.parse
from pathlib import Path
UA = {"User-Agent": "Mozilla/5.0 (compatible; picos3d-datos/1.0)"}
col, out, *filters = sys.argv[1:]
# caja del mapa (raw/extension_latlon.txt: lat_min,lon_min,lat_max,lon_max) en el orden lon,lat de la OGC API
la0, lo0, la1, lo1 = Path(__file__).resolve().parent.parent.joinpath("raw", "extension_latlon.txt").read_text().strip().split(",")
params = {"f": "json", "limit": "2000", "bbox": f"{lo0},{la0},{lo1},{la1}"}
for f in filters:
    k, v = f.split("=", 1); params[k] = v
url = f"https://api-features.idee.es/collections/{col}/items?" + urllib.parse.urlencode(params)
feats = []
while url:
    for attempt in range(8):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=300) as r:
                d = json.load(r); break
        except Exception as e:
            print("reintento", attempt, e, flush=True); time.sleep(5 * (attempt + 1))
    else:
        sys.exit("fallo definitivo en " + url)
    feats += d["features"]
    print(col, filters, len(feats), "/", d.get("numberMatched"), flush=True)
    url = next((l["href"] for l in d.get("links", []) if l.get("rel") == "next"), None)
json.dump({"type": "FeatureCollection", "features": feats}, open(out, "w"))
print("OK", out, len(feats))
