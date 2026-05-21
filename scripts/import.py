#!/usr/bin/env python3
"""
Exports Custom Formats and Quality Profiles from Radarr/Sonarr
and converts them to the Profilarr Compliant Database (PCD) format.

Prerequisites:
    pip install requests pyyaml python-dotenv

Usage (from repo root):
    python scripts/import.py [options]

Usage (from scripts/):
    python import.py [options]

Configuration can be supplied via CLI args, a .env file, or both
(CLI args take precedence over .env values).

.env variables:
    RADARR_URL, RADARR_API_KEY
    SONARR_URL, SONARR_API_KEY
    DB_NAME, DB_DESCRIPTION, DB_AUTHOR, DB_REPO
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

import urllib3
import requests
import yaml

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parent.parent / ".env")
    load_dotenv(Path(__file__).resolve().parent / ".env")
except ImportError:
    pass  # python-dotenv not installed; .env files will be ignored

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ─── Mapping tables ───────────────────────────────────────────────────────────

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

# ─── API helpers ──────────────────────────────────────────────────────────────

def api_get(base_url: str, api_key: str, endpoint: str) -> Any:
    url = f"{base_url.rstrip('/')}/api/v3/{endpoint}"
    try:
        resp = requests.get(url, headers={"X-Api-Key": api_key}, timeout=30, verify=False)
        resp.raise_for_status()
        return resp.json()
    except requests.exceptions.ConnectionError:
        print(f"  [ERROR] Could not connect to {base_url}.", file=sys.stderr)
        sys.exit(1)
    except requests.exceptions.HTTPError as e:
        print(f"  [ERROR] HTTP {e.response.status_code} from {url}", file=sys.stderr)
        sys.exit(1)


def get_field(fields: list[dict], name: str) -> Any:
    for f in fields:
        if f.get("name") == name:
            return f.get("value")
    return None

# ─── Custom Format conversion ─────────────────────────────────────────────────

def convert_condition(spec: dict) -> dict | None:
    impl = spec.get("implementation", "")
    cond_type = IMPL_TO_TYPE.get(impl)
    if not cond_type:
        print(f"    [WARN] Unknown implementation ignored: {impl}", file=sys.stderr)
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

# ─── Quality Profile conversion ───────────────────────────────────────────────

def build_qualities(items: list[dict], cutoff_id: int) -> tuple[list[dict], dict | None]:
    result = []
    upgrade_until = None
    group_counter = -1

    for item in items:
        if "quality" in item:
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
                "name":      item.get("name", "Group"),
                "qualities": sub_qualities,
            }
            result.append(group_entry)

            if is_cutoff_group:
                upgrade_until = {"id": group_counter, "name": item.get("name", "Group")}

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

# ─── File helpers ─────────────────────────────────────────────────────────────

def safe_filename(name: str) -> str:
    for ch in r'/\:*?"<>|':
        name = name.replace(ch, "-")
    return name.strip()


def write_yaml(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)
    print(f"  + {path}")

# ─── CLI ──────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export Custom Formats and Quality Profiles from Radarr/Sonarr to PCD format."
    )

    radarr = parser.add_argument_group("Radarr")
    radarr.add_argument("--radarr-url",     default=os.getenv("RADARR_URL"),     metavar="URL",
                        help="Radarr base URL (env: RADARR_URL)")
    radarr.add_argument("--radarr-api-key", default=os.getenv("RADARR_API_KEY"), metavar="KEY",
                        help="Radarr API key (env: RADARR_API_KEY)")
    radarr.add_argument("--no-radarr", action="store_true",
                        help="Skip Radarr export")

    sonarr = parser.add_argument_group("Sonarr")
    sonarr.add_argument("--sonarr-url",     default=os.getenv("SONARR_URL"),     metavar="URL",
                        help="Sonarr base URL (env: SONARR_URL)")
    sonarr.add_argument("--sonarr-api-key", default=os.getenv("SONARR_API_KEY"), metavar="KEY",
                        help="Sonarr API key (env: SONARR_API_KEY)")
    sonarr.add_argument("--no-sonarr", action="store_true",
                        help="Skip Sonarr export")

    meta = parser.add_argument_group("Database metadata")
    meta.add_argument("--name",        default=os.getenv("DB_NAME",        "my-profilarr-db"),
                      help="Database name written to pcd.json (env: DB_NAME)")
    meta.add_argument("--description", default=os.getenv("DB_DESCRIPTION", ""),
                      help="Database description written to pcd.json (env: DB_DESCRIPTION)")
    meta.add_argument("--author",      default=os.getenv("DB_AUTHOR",      ""),
                      help="Author name written to pcd.json (env: DB_AUTHOR)")
    meta.add_argument("--repo",        default=os.getenv("DB_REPO",        ""),
                      help="Repository URL written to pcd.json (env: DB_REPO)")

    return parser.parse_args()

# ─── Main ─────────────────────────────────────────────────────────────────────

def main() -> None:
    args = parse_args()

    export_radarr = not args.no_radarr and bool(args.radarr_url and args.radarr_api_key)
    export_sonarr = not args.no_sonarr and bool(args.sonarr_url and args.sonarr_api_key)

    if not export_radarr and not export_sonarr:
        print(
            "[ERROR] No source configured. Provide Radarr/Sonarr credentials via CLI args or a .env file.\n"
            "        Run with --help for details.",
            file=sys.stderr,
        )
        sys.exit(1)

    out = Path(__file__).resolve().parent.parent

    print("Creating directory structure...")
    for folder in ["custom_formats", "profiles", "regex_patterns", "media_management", "templates"]:
        d = out / folder
        d.mkdir(parents=True, exist_ok=True)
        (d / ".gitkeep").touch()

    radarr_cfs: list[dict] = []
    sonarr_cfs: list[dict] = []
    radarr_qps: list[dict] = []
    sonarr_qps: list[dict] = []

    # ── Fetch Custom Formats ──────────────────────────────────────────
    if export_radarr:
        print("\nFetching Radarr Custom Formats...")
        radarr_cfs = api_get(args.radarr_url, args.radarr_api_key, "customformat")
        print(f"  {len(radarr_cfs)} custom formats found.")

    if export_sonarr:
        print("\nFetching Sonarr Custom Formats...")
        sonarr_cfs = api_get(args.sonarr_url, args.sonarr_api_key, "customformat")
        print(f"  {len(sonarr_cfs)} custom formats found.")

    # Deduplicate: same name → Radarr takes precedence
    cf_by_name: dict[str, dict] = {}
    for cf in sonarr_cfs:
        cf_by_name[cf["name"]] = cf
    for cf in radarr_cfs:
        cf_by_name[cf["name"]] = cf

    print(f"\nWriting {len(cf_by_name)} custom formats...")
    for name, cf in cf_by_name.items():
        pcd_cf = convert_custom_format(cf)
        write_yaml(out / "custom_formats" / (safe_filename(name) + ".yml"), pcd_cf)

    # ── Fetch Quality Profiles ────────────────────────────────────────
    if export_radarr:
        print("\nFetching Radarr Quality Profiles...")
        radarr_qps = api_get(args.radarr_url, args.radarr_api_key, "qualityprofile")
        print(f"  {len(radarr_qps)} profiles found.")

    if export_sonarr:
        print("\nFetching Sonarr Quality Profiles...")
        sonarr_qps = api_get(args.sonarr_url, args.sonarr_api_key, "qualityprofile")
        print(f"  {len(sonarr_qps)} profiles found.")

    radarr_cf_map: dict[int, str] = {cf["id"]: cf["name"] for cf in radarr_cfs}
    sonarr_cf_map: dict[int, str] = {cf["id"]: cf["name"] for cf in sonarr_cfs}

    radarr_by_name = {qp["name"]: qp for qp in radarr_qps}
    sonarr_by_name = {qp["name"]: qp for qp in sonarr_qps}
    all_profile_names = set(radarr_by_name) | set(sonarr_by_name)

    print(f"\nWriting {len(all_profile_names)} quality profiles...")
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

    # ── pcd.json manifest ─────────────────────────────────────────────
    print("\nWriting pcd.json...")
    arr_types = []
    if export_radarr:
        arr_types.append("radarr")
    if export_sonarr:
        arr_types.append("sonarr")

    manifest: dict[str, Any] = {
        "name":        args.name,
        "version":     "1.0.0",
        "description": args.description,
        "arr_types":   arr_types,
        "authors":     [{"name": args.author}] if args.author else [],
        "dependencies": {
            "https://github.com/Dictionarry-Hub/schema": "1.1.0",
        },
        "profilarr": {
            "minimum_version": "2.0.0",
        },
    }
    if args.repo:
        manifest["repository"] = args.repo

    manifest_path = out / "pcd.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=4, ensure_ascii=False)
    print(f"  + {manifest_path}")

    print(f"""
╔══════════════════════════════════════════════════════════╗
  Done! Database written to: {out.resolve()}

  Next steps:
  1. git add . && git commit -m "update export"
  2. Push repository to GitHub/Gitea
  3. In Profilarr: Settings → Database → Add Remote Repo
     → Enter your repository URL

  Tip: Review the generated YAML files and adjust
  'description' and 'tags' as needed.
╚══════════════════════════════════════════════════════════╝
""")


if __name__ == "__main__":
    main()
