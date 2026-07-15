#!/usr/bin/env python3
"""Borra TODOS los territorios (colección `zones`) para empezar el mundo limpio
con el nuevo modelo "territorio libre".

Uso:
    gcloud config set account myscraper.llc.2021@gmail.com
    python scripts/clear_zones.py

Borra las 25 zonas de distritos sembradas del modelo antiguo. Los nuevos
territorios se crean solos cuando los jugadores cierran cercos corriendo.
"""
import json, subprocess, sys, urllib.request, urllib.error

PROJECT = "trazos-database"
BASE = (f"https://firestore.googleapis.com/v1/projects/{PROJECT}"
        f"/databases/(default)/documents/zones")


def token():
    out = subprocess.run(["gcloud", "auth", "print-access-token"],
                         capture_output=True, text=True, shell=True)
    t = out.stdout.strip()
    if not t:
        sys.exit("No pude obtener token de gcloud. Haz 'gcloud auth login'.")
    return t


def req(method, url):
    r = urllib.request.Request(url, method=method,
                               headers={"Authorization": "Bearer " + token()})
    try:
        return urllib.request.urlopen(r).read().decode()
    except urllib.error.HTTPError as e:
        return f"ERROR {e.code}: {e.read().decode()[:200]}"


def main():
    listing = json.loads(req("GET", BASE + "?pageSize=300"))
    docs = listing.get("documents", [])
    print(f"Zonas encontradas: {len(docs)}")
    for d in docs:
        name = d["name"]  # ruta completa del documento
        url = "https://firestore.googleapis.com/v1/" + name
        res = req("DELETE", url)
        short = name.split("/")[-1]
        print("  borrada", short if "ERROR" not in res else short + " -> " + res)
    print("Listo. Mundo limpio.")


if __name__ == "__main__":
    main()
