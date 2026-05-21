#!/usr/bin/env python3
"""
Exportiert Custom Formats und Quality Profiles aus Radarr/Sonarr
und konvertiert sie ins Profilarr Compliant Database (PCD) Format.

Voraussetzungen:
    pip install requests pyyaml

Verwendung (aus dem Repo-Root):
    python scripts/arr_to_pcd.py

Verwendung (aus scripts/):
    python arr_to_pcd.py
"""

import json
import sys
from pathlib import Path
from typing import Any

import urllib3
import requests
import yaml

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ─── Konfiguration ────────────────────────────────────────────────────────────

RADARR_URL     = "https://radarr.microos.fritz.box/"
RADARR_API_KEY = "a76573c5dbbf412ca2f241155eb8fc59"

SONARR_URL     = "https://sonarr.microos.fritz.box/"
SONARR_API_KEY = "d803b6476f954d0ea4452bc6caad81f4"

# Ausgabe-Verzeichnis: Repo-Root (ein Verzeichnis über scripts/)
OUTPUT_DIR = Path(__file__).resolve().parent.parent

# pcd.json Metadaten
DB_NAME        = "wirehack7-arr-profilarr-db"
DB_DESCRIPTION = "A Profilarr database exported from Radarr and Sonarr"
DB_AUTHOR      = "wirehack7"
DB_REPO        = ""  # z.B. https://github.com/deinname/profilarr-db

# Auf False setzen um eine App zu überspringen
EXPORT_RADARR = True
EXPORT_SONARR = True

# ─── Mapping-Tabellen ─────────────────────────────────────────────────────────

IMPL_TO_TYPE: dict[str, str] = {
    "ReleaseTitleSpecification":    "release_title",
    "ReleaseGroupSpecification":    "release_group",
    "LanguageSpecification":        "language",
    "IndexerFlagSpecification":     "indexer_flag",
    "SourceSpecification":          "source",
    "ResolutionSpecification":      "resolution",
    "QualityModifierSpecification": "quality_modifier",
    "SizeSpecification":            "size",
    "ReleaseTypeSpecification":     "release_type",
    "YearSpecification":            "year",
    "EditionSpecification":         "edition",
}

SOURCE_MAP: dict[int, str] = {
    0: "unknown",
    1: "cam",
    2: "telesync",
    3: "telecine",
    4: "workprint",
    5: "dvd",
    6: "television",
    7: "webrip",
    8: "webdl",
    9: "bluray",
}

RESOLUTION_MAP: dict[int, str] = {
    0:    "unknown",
    360:  "360p",
    480:  "480p",
    576:  "576p",
    720:  "720p",
    1080: "1080p",
    2160: "2160p",
}

QUALITY_MODIFIER_MAP: dict[int, str] = {
    0: "none",
    1: "regional",
    2: "screener",
    3: "rawhd",
    4: "brdisk",
    5: "remux",
}

LANGUAGE_MAP: dict[int, str] = {
    -2: "any",
    -1: "original",
    1:  "english",
    2:  "french",
    3:  "spanish",
    4:  "german",
    5:  "italian",
    6:  "danish",
    7:  "dutch",
    8:  "japanese",
    9:  "icelandic",
    10: "chinese",
    11: "russian",
    12: "polish",
    13: "vietnamese",
    14: "swedish",
    15: "norwegian",
    16: "finnish",
    17: "turkish",
    18: "portuguese",
    19: "flemish",
    20: "greek",
    21: "korean",
    22: "hungarian",
    23: "hebrew",
    24: "lithuanian",
    25: "czech",
    26: "hindi",
    27: "romanian",
    28: "thai",
    29: "bulgarian",
    30: "arabic",
    31: "ukrainian",
    32: "persian",
    33: "bengali",
    34: "slovak",
    40: "portuguese (brazil)",
    44: "tagalog",
    46: "macedonian",
}

# ─── API-Hilfsfunktionen ──────────────────────────────────────────────────────

def api_get(base_url: str, api_key: str, endpoint: str) -> Any:
    url = f"{base_url.rstrip('/')}/api/v3/{endpoint}"
    try:
        resp = requests.get(url, headers={"X-Api-Key": api_key}, timeout=30, verify=False)
        resp.raise_for_status()
        return resp.json()
    except requests.exceptions.ConnectionError:
        print(f"  [FEHLER] Verbindung zu {base_url} fehlgeschlagen.", file=sys.stderr)
        sys.exit(1)
    except requests.exceptions.HTTPError as e:
        print(f"  [FEHLER] HTTP {e.response.status_code} von {url}", file=sys.stderr)
        sys.exit(1)


def get_field(fields: list[dict], name: str) -> Any:
    for f in fields:
        if f.get("name") == name:
            return f.get("value")
    return None

# ─── Custom Format Konvertierung ──────────────────────────────────────────────

def convert_condition(spec: dict) -> dict | None:
    impl = spec.get("implementation", "")
    cond_type = IMPL_TO_TYPE.get(impl)
    if not cond_type:
        print(f"    [WARN] Unbekannte Implementation ignoriert: {impl}", file=sys.stderr)
        return None

    fields = spec.get("fields", [])
    cond: dict[str, Any] = {
        "name":     spec["name"],
        "type":     cond_type,
        "negate":   spec.get("negate", False),
        "required": spec.get("required", True),
    }

    if cond_type in ("release_title", "release_group", "edition"):
        cond["pattern"] = get_field(fields, "value") or ""

    elif cond_type == "source":
        raw = get_field(fields, "value")
        cond["source"] = SOURCE_MAP.get(raw, str(raw)) if raw is not None else "unknown"

    elif cond_type == "resolution":
        raw = get_field(fields, "value")
        cond["resolution"] = RESOLUTION_MAP.get(raw, str(raw)) if raw is not None else "unknown"

    elif cond_type == "language":
        raw = get_field(fields, "value")
        cond["language"] = LANGUAGE_MAP.get(raw, str(raw)) if raw is not None else "unknown"
        except_lang = get_field(fields, "exceptLanguage")
        if except_lang:
            cond["exceptLanguage"] = True

    elif cond_type == "indexer_flag":
        cond["flag"] = get_field(fields, "value")

    elif cond_type == "quality_modifier":
        raw = get_field(fields, "value")
        cond["quality_modifier"] = QUALITY_MODIFIER_MAP.get(raw, str(raw)) if raw is not None else "none"

    elif cond_type == "size":
        cond["min_bytes"] = get_field(fields, "min") or 0
        cond["max_bytes"] = get_field(fields, "max") or 0

    elif cond_type == "year":
        cond["min_year"] = get_field(fields, "min") or 0
        cond["max_year"] = get_field(fields, "max") or 0

    elif cond_type == "release_type":
        cond["release_type"] = get_field(fields, "value")

    return cond


def convert_custom_format(cf: dict) -> dict:
    conditions = []
    for spec in cf.get("specifications", []):
        cond = convert_condition(spec)
        if cond:
            conditions.append(cond)

    return {
        "name":                     cf["name"],
        "description":              "",
        "includeCustomFormatWhenRenaming": cf.get("includeCustomFormatWhenRenaming", False),
        "tags":                     [],
        "conditions":               conditions,
        "tests":                    [],
    }

# ─── Quality Profile Konvertierung ────────────────────────────────────────────

def build_qualities(items: list[dict], cutoff_id: int) -> tuple[list[dict], dict | None]:
    """
    Konvertiert Radarr/Sonarr-Qualitäten ins PCD-Format.
    Gibt (qualities_list, upgrade_until_entry) zurück.
    Nur enabled=true Qualitäten werden in die Liste aufgenommen.
    """
    result = []
    upgrade_until = None
    group_counter = -1

    for item in items:
        if "quality" in item:
            # Einzelne Qualität
            q = item["quality"]
            if not item.get("allowed", True):
                continue
            entry: dict[str, Any] = {
                "id":   q["id"],
                "name": q["name"],
            }
            result.append(entry)
            if q["id"] == cutoff_id:
                upgrade_until = {"id": q["id"], "name": q["name"]}
        else:
            # Qualitätsgruppe
            sub_qualities = []
            is_cutoff_group = False
            for sub_item in item.get("items", []):
                q = sub_item["quality"]
                if sub_item.get("allowed", True):
                    sub_qualities.append({
                        "id":   q["id"],
                        "name": q["name"],
                    })
                if q["id"] == cutoff_id:
                    is_cutoff_group = True

            if not item.get("allowed", True) and not sub_qualities:
                continue

            group_entry: dict[str, Any] = {
                "id":        group_counter,
                "name":      item.get("name", "Gruppe"),
                "qualities": sub_qualities,
            }
            result.append(group_entry)

            if is_cutoff_group:
                upgrade_until = {"id": group_counter, "name": item.get("name", "Gruppe")}

            group_counter -= 1

    return result, upgrade_until


def extract_format_scores(profile: dict, cf_id_to_name: dict[int, str]) -> list[dict]:
    scores = []
    for fi in profile.get("formatItems", []):
        score = fi.get("score", 0)
        if score == 0:
            continue
        name = cf_id_to_name.get(fi["format"], fi.get("name", f"Format_{fi['format']}"))
        scores.append({"name": name, "score": score})
    return sorted(scores, key=lambda x: -x["score"])


def convert_quality_profile(profile: dict, cf_id_to_name: dict[int, str]) -> dict:
    cutoff_id = profile.get("cutoff", 0)
    format_scores = extract_format_scores(profile, cf_id_to_name)
    qualities, upgrade_until = build_qualities(profile.get("items", []), cutoff_id)

    result: dict[str, Any] = {
        "name":                 profile["name"],
        "description":          "",
        "tags":                 [],
        "upgradesAllowed":      profile.get("upgradeAllowed", True),
        "minCustomFormatScore": profile.get("minFormatScore", 0),
        "upgradeUntilScore":    profile.get("cutoffFormatScore", 888888),
        "minScoreIncrement":    profile.get("minUpgradeFormatScore", 1),
        "custom_formats":       format_scores,
        "custom_formats_radarr": [],
        "custom_formats_sonarr": [],
        "qualities":            qualities,
    }
    if upgrade_until:
        result["upgrade_until"] = upgrade_until

    return result


def merge_profile_scores(
    radarr_profile: dict,
    sonarr_profile: dict,
    radarr_cf_map: dict[int, str],
    sonarr_cf_map: dict[int, str],
) -> dict:
    """Erstellt ein zusammengeführtes Profil mit shared/radarr/sonarr Scores."""
    base = convert_quality_profile(radarr_profile, radarr_cf_map)
    sonarr_scores = extract_format_scores(sonarr_profile, sonarr_cf_map)

    radarr_scores_by_name = {e["name"]: e["score"] for e in base["custom_formats"]}
    sonarr_scores_by_name = {e["name"]: e["score"] for e in sonarr_scores}

    shared, only_radarr, only_sonarr = [], [], []
    all_names = set(radarr_scores_by_name) | set(sonarr_scores_by_name)

    for cf_name in all_names:
        r = radarr_scores_by_name.get(cf_name)
        s = sonarr_scores_by_name.get(cf_name)
        if r == s and r is not None:
            shared.append({"name": cf_name, "score": r})
        else:
            if r is not None:
                only_radarr.append({"name": cf_name, "score": r})
            if s is not None:
                only_sonarr.append({"name": cf_name, "score": s})

    base["custom_formats"]        = sorted(shared,      key=lambda x: -x["score"])
    base["custom_formats_radarr"] = sorted(only_radarr, key=lambda x: -x["score"])
    base["custom_formats_sonarr"] = sorted(only_sonarr, key=lambda x: -x["score"])
    return base

# ─── Datei-Hilfsfunktionen ────────────────────────────────────────────────────

def safe_filename(name: str) -> str:
    for ch in r'/\:*?"<>|':
        name = name.replace(ch, "-")
    return name.strip()


def write_yaml(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)
    print(f"  + {path}")

# ─── Hauptprogramm ────────────────────────────────────────────────────────────

def main() -> None:
    out = Path(OUTPUT_DIR)

    # Verzeichnisstruktur anlegen
    print("Erstelle Verzeichnisstruktur...")
    for folder in ["custom_formats", "profiles", "regex_patterns", "media_management", "templates"]:
        d = out / folder
        d.mkdir(parents=True, exist_ok=True)
        (d / ".gitkeep").touch()

    radarr_cfs: list[dict] = []
    sonarr_cfs: list[dict] = []
    radarr_qps: list[dict] = []
    sonarr_qps: list[dict] = []

    # ── Custom Formats abrufen ───────────────────────────────────────
    if EXPORT_RADARR:
        print("\nRufe Radarr Custom Formats ab...")
        radarr_cfs = api_get(RADARR_URL, RADARR_API_KEY, "customformat")
        print(f"  {len(radarr_cfs)} Custom Formats gefunden.")

    if EXPORT_SONARR:
        print("\nRufe Sonarr Custom Formats ab...")
        sonarr_cfs = api_get(SONARR_URL, SONARR_API_KEY, "customformat")
        print(f"  {len(sonarr_cfs)} Custom Formats gefunden.")

    # Deduplizierung: gleicher Name → Radarr hat Vorrang
    cf_by_name: dict[str, dict] = {}
    for cf in sonarr_cfs:
        cf_by_name[cf["name"]] = cf
    for cf in radarr_cfs:
        cf_by_name[cf["name"]] = cf  # überschreibt Sonarr bei gleichem Namen

    print(f"\nSchreibe {len(cf_by_name)} Custom Formats...")
    for name, cf in cf_by_name.items():
        pcd_cf = convert_custom_format(cf)
        write_yaml(out / "custom_formats" / (safe_filename(name) + ".yml"), pcd_cf)

    # ── Quality Profiles abrufen ─────────────────────────────────────
    if EXPORT_RADARR:
        print("\nRufe Radarr Quality Profiles ab...")
        radarr_qps = api_get(RADARR_URL, RADARR_API_KEY, "qualityprofile")
        print(f"  {len(radarr_qps)} Profile gefunden.")

    if EXPORT_SONARR:
        print("\nRufe Sonarr Quality Profiles ab...")
        sonarr_qps = api_get(SONARR_URL, SONARR_API_KEY, "qualityprofile")
        print(f"  {len(sonarr_qps)} Profile gefunden.")

    radarr_cf_map: dict[int, str] = {cf["id"]: cf["name"] for cf in radarr_cfs}
    sonarr_cf_map: dict[int, str] = {cf["id"]: cf["name"] for cf in sonarr_cfs}

    radarr_by_name = {qp["name"]: qp for qp in radarr_qps}
    sonarr_by_name = {qp["name"]: qp for qp in sonarr_qps}
    all_profile_names = set(radarr_by_name) | set(sonarr_by_name)

    print(f"\nSchreibe {len(all_profile_names)} Quality Profiles...")
    for name in all_profile_names:
        in_radarr = name in radarr_by_name
        in_sonarr = name in sonarr_by_name

        if in_radarr and in_sonarr:
            pcd = merge_profile_scores(
                radarr_by_name[name], sonarr_by_name[name],
                radarr_cf_map, sonarr_cf_map,
            )
        elif in_radarr:
            pcd = convert_quality_profile(radarr_by_name[name], radarr_cf_map)
            pcd["custom_formats_radarr"] = pcd.pop("custom_formats")
            pcd["custom_formats"] = []
        else:
            pcd = convert_quality_profile(sonarr_by_name[name], sonarr_cf_map)
            pcd["custom_formats_sonarr"] = pcd.pop("custom_formats")
            pcd["custom_formats"] = []

        write_yaml(out / "profiles" / (safe_filename(name) + ".yml"), pcd)

    # ── pcd.json Manifest ────────────────────────────────────────────
    print("\nSchreibe pcd.json...")
    arr_types = []
    if EXPORT_RADARR:
        arr_types.append("radarr")
    if EXPORT_SONARR:
        arr_types.append("sonarr")

    manifest: dict[str, Any] = {
        "name":        DB_NAME,
        "version":     "1.0.0",
        "description": DB_DESCRIPTION,
        "arr_types":   arr_types,
        "authors":     [{"name": DB_AUTHOR}],
        "dependencies": {
            "schema": "^1.1.0",
        },
        "profilarr": {
            "minimum_version": "2.0.0",
        },
    }
    if DB_REPO:
        manifest["repository"] = DB_REPO

    manifest_path = out / "pcd.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=4, ensure_ascii=False)
    print(f"  + {manifest_path}")

    # ── Zusammenfassung ──────────────────────────────────────────────
    print(f"""
╔══════════════════════════════════════════════════════════╗
  Fertig! Datenbank geschrieben nach: {out.resolve()}

  Nächste Schritte:
  1. git add . && git commit -m "update export"
  2. Repository auf GitHub/Gitea pushen
  3. In Profilarr: Settings → Database → Add Remote Repo
     → URL deines Repos eintragen

  Hinweis: Prüfe die generierten YAML-Dateien und passe
  'description' und 'tags' nach Bedarf an.
╚══════════════════════════════════════════════════════════╝
""")


if __name__ == "__main__":
    main()
