#!/usr/bin/env python3
"""
Exports Custom Formats and Quality Profiles from Radarr/Sonarr
and writes them as a PCD-compliant SQL ops file (ops/1.initial.sql).

Prerequisites:
    pip install -r scripts/requirements.txt

Usage:
    python scripts/import.py [options]

Configuration via CLI args or .env file (CLI takes precedence):
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

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parent.parent / ".env")
    load_dotenv(Path(__file__).resolve().parent / ".env")
except ImportError:
    pass

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
    0: "unknown", 1: "cam", 2: "telesync", 3: "telecine",
    4: "workprint", 5: "dvd", 6: "television", 7: "webrip",
    8: "webdl", 9: "bluray",
}

RESOLUTION_MAP: dict[int, str] = {
    0: "unknown", 360: "360p", 480: "480p", 576: "576p",
    720: "720p", 1080: "1080p", 2160: "2160p",
}

QUALITY_MODIFIER_MAP: dict[int, str] = {
    0: "none", 1: "regional", 2: "screener",
    3: "rawhd", 4: "brdisk", 5: "remux",
}

# Names must match schema ops/1.languages.sql exactly (Title Case)
LANGUAGE_MAP: dict[int, str] = {
    -2: "Any",
    -1: "Original",
    1:  "English",
    2:  "French",
    3:  "Spanish",
    4:  "German",
    5:  "Italian",
    6:  "Danish",
    7:  "Dutch",
    8:  "Japanese",
    9:  "Icelandic",
    10: "Chinese",
    11: "Russian",
    12: "Polish",
    13: "Vietnamese",
    14: "Swedish",
    15: "Norwegian",
    16: "Finnish",
    17: "Turkish",
    18: "Portuguese",
    19: "Flemish",
    20: "Greek",
    21: "Korean",
    22: "Hungarian",
    23: "Hebrew",
    24: "Lithuanian",
    25: "Czech",
    26: "Hindi",
    27: "Romanian",
    28: "Thai",
    29: "Bulgarian",
    30: "Arabic",
    31: "Ukrainian",
    32: "Persian",
    33: "Bengali",
    34: "Slovak",
    40: "Portuguese (Brazil)",
    44: "Tagalog",
    46: "Macedonian",
}

# Sonarr uses different API names for remux qualities
SONARR_QUALITY_NAME_MAP: dict[str, str] = {
    "Bluray-1080p Remux": "Remux-1080p",
    "Bluray-2160p Remux": "Remux-2160p",
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

# ─── SQL helpers ──────────────────────────────────────────────────────────────

def q(s: Any) -> str:
    """Quote a value for SQL INSERT. None → NULL, bool/int → bare integer, str → escaped."""
    if s is None:
        return "NULL"
    if isinstance(s, bool):
        return "1" if s else "0"
    if isinstance(s, (int, float)):
        return str(s)
    return "'" + str(s).replace("'", "''") + "'"

# ─── Custom Formats ───────────────────────────────────────────────────────────

def build_custom_formats_sql(
    cf_by_name: dict[str, dict],
    cf_source: dict[str, str],
) -> dict[str, list[str]]:
    """
    Returns a dict with keys matching ops file names:
      'regular_expressions', 'custom_formats', 'custom_format_conditions'
    """
    cf_lines:      list[str] = []
    regex_lines:   list[str] = []
    cond_lines:    list[str] = []
    pattern_lines: list[str] = []
    source_lines:  list[str] = []
    res_lines:     list[str] = []
    lang_lines:    list[str] = []
    flag_lines:    list[str] = []
    qmod_lines:    list[str] = []
    size_lines:    list[str] = []
    year_lines:    list[str] = []
    rtype_lines:   list[str] = []

    used_regex: set[str] = set()

    for cf_name, cf in sorted(cf_by_name.items()):
        arr_type = cf_source.get(cf_name, "all")
        include  = 1 if cf.get("includeCustomFormatWhenRenaming", False) else 0

        cf_lines.append(
            f"INSERT INTO custom_formats (name, description, include_in_rename) "
            f"VALUES ({q(cf_name)}, {q('')}, {include});"
        )

        for spec in cf.get("specifications", []):
            impl      = spec.get("implementation", "")
            cond_type = IMPL_TO_TYPE.get(impl)
            if not cond_type:
                print(f"    [WARN] Unknown implementation ignored: {impl}", file=sys.stderr)
                continue

            cond_name = spec["name"]
            negate    = 1 if spec.get("negate", False) else 0
            required  = 1 if spec.get("required", True) else 0
            fields    = spec.get("fields", [])

            cond_lines.append(
                f"INSERT INTO custom_format_conditions "
                f"(custom_format_name, name, type, arr_type, negate, required) "
                f"VALUES ({q(cf_name)}, {q(cond_name)}, {q(cond_type)}, {q(arr_type)}, {negate}, {required});"
            )

            if cond_type in ("release_title", "release_group", "edition"):
                pattern    = get_field(fields, "value") or ""
                regex_name = f"{cf_name} :: {cond_name}"
                base, n = regex_name, 2
                while regex_name in used_regex:
                    regex_name = f"{base} ({n})"
                    n += 1
                used_regex.add(regex_name)

                regex_lines.append(
                    f"INSERT INTO regular_expressions (name, pattern) "
                    f"VALUES ({q(regex_name)}, {q(pattern)});"
                )
                pattern_lines.append(
                    f"INSERT INTO condition_patterns "
                    f"(custom_format_name, condition_name, regular_expression_name) "
                    f"VALUES ({q(cf_name)}, {q(cond_name)}, {q(regex_name)});"
                )

            elif cond_type == "source":
                raw = get_field(fields, "value")
                src = SOURCE_MAP.get(raw, str(raw)) if raw is not None else "unknown"
                source_lines.append(
                    f"INSERT INTO condition_sources "
                    f"(custom_format_name, condition_name, source) "
                    f"VALUES ({q(cf_name)}, {q(cond_name)}, {q(src)});"
                )

            elif cond_type == "resolution":
                raw = get_field(fields, "value")
                res = RESOLUTION_MAP.get(raw, str(raw)) if raw is not None else "unknown"
                res_lines.append(
                    f"INSERT INTO condition_resolutions "
                    f"(custom_format_name, condition_name, resolution) "
                    f"VALUES ({q(cf_name)}, {q(cond_name)}, {q(res)});"
                )

            elif cond_type == "language":
                raw       = get_field(fields, "value")
                lang      = LANGUAGE_MAP.get(raw, str(raw)) if raw is not None else "Unknown"
                exc_lang  = 1 if get_field(fields, "exceptLanguage") else 0
                lang_lines.append(
                    f"INSERT INTO condition_languages "
                    f"(custom_format_name, condition_name, language_name, except_language) "
                    f"VALUES ({q(cf_name)}, {q(cond_name)}, {q(lang)}, {exc_lang});"
                )

            elif cond_type == "indexer_flag":
                flag = get_field(fields, "value")
                flag_lines.append(
                    f"INSERT INTO condition_indexer_flags "
                    f"(custom_format_name, condition_name, flag) "
                    f"VALUES ({q(cf_name)}, {q(cond_name)}, {q(flag)});"
                )

            elif cond_type == "quality_modifier":
                raw  = get_field(fields, "value")
                qmod = QUALITY_MODIFIER_MAP.get(raw, str(raw)) if raw is not None else "none"
                qmod_lines.append(
                    f"INSERT INTO condition_quality_modifiers "
                    f"(custom_format_name, condition_name, quality_modifier) "
                    f"VALUES ({q(cf_name)}, {q(cond_name)}, {q(qmod)});"
                )

            elif cond_type == "size":
                min_b = get_field(fields, "min") or 0
                max_b = get_field(fields, "max") or 0
                size_lines.append(
                    f"INSERT INTO condition_sizes "
                    f"(custom_format_name, condition_name, min_bytes, max_bytes) "
                    f"VALUES ({q(cf_name)}, {q(cond_name)}, {min_b}, {max_b});"
                )

            elif cond_type == "year":
                min_y = get_field(fields, "min") or 0
                max_y = get_field(fields, "max") or 0
                year_lines.append(
                    f"INSERT INTO condition_years "
                    f"(custom_format_name, condition_name, min_year, max_year) "
                    f"VALUES ({q(cf_name)}, {q(cond_name)}, {min_y}, {max_y});"
                )

            elif cond_type == "release_type":
                rt = get_field(fields, "value")
                rtype_lines.append(
                    f"INSERT INTO condition_release_types "
                    f"(custom_format_name, condition_name, release_type) "
                    f"VALUES ({q(cf_name)}, {q(cond_name)}, {q(rt)});"
                )

    conditions_out: list[str] = []
    for header, lines in [
        ("-- Custom Format Conditions",    cond_lines),
        ("-- Condition Patterns",          pattern_lines),
        ("-- Condition Sources",           source_lines),
        ("-- Condition Resolutions",       res_lines),
        ("-- Condition Languages",         lang_lines),
        ("-- Condition Indexer Flags",     flag_lines),
        ("-- Condition Quality Modifiers", qmod_lines),
        ("-- Condition Sizes",             size_lines),
        ("-- Condition Years",             year_lines),
        ("-- Condition Release Types",     rtype_lines),
    ]:
        if lines:
            conditions_out += [header, ""] + lines + [""]

    return {
        "regular_expressions":      regex_lines,
        "custom_formats":           cf_lines,
        "custom_format_conditions": conditions_out,
    }

# ─── Quality Profiles ─────────────────────────────────────────────────────────

def extract_format_scores(profile: dict, cf_id_to_name: dict[int, str]) -> list[dict]:
    scores = []
    for fi in profile.get("formatItems", []):
        score = fi.get("score", 0)
        if score == 0:
            continue
        name = cf_id_to_name.get(fi["format"], fi.get("name", f"Format_{fi['format']}"))
        scores.append({"name": name, "score": score})
    return scores


def normalize_quality_name(name: str, arr_type: str) -> str:
    if arr_type == "sonarr":
        return SONARR_QUALITY_NAME_MAP.get(name, name)
    return name


# Resolution keywords → tag name
_TAG_PATTERNS: list[tuple[str, str]] = [
    ("german",  "German"),
    ("480p",    "480p"),
    ("576p",    "576p"),
    ("720p",    "720p"),
    ("1080p",   "1080p"),
    ("2160p",   "4K"),
    ("4k",      "4K"),
    ("ultra",   "4K"),
]

def profile_tags(name: str) -> list[str]:
    lower = name.lower()
    seen:  list[str] = []
    for keyword, tag in _TAG_PATTERNS:
        if keyword in lower and tag not in seen:
            seen.append(tag)
    return seen


def build_quality_profiles_sql(
    radarr_qps: list[dict],
    sonarr_qps: list[dict],
    radarr_cf_map: dict[int, str],
    sonarr_cf_map: dict[int, str],
) -> dict[str, list[str]]:
    """
    Returns a dict with keys:
      'quality_profiles', 'quality_profile_qualities', 'quality_profile_scores'
    """
    profile_lines:  list[str] = []
    group_lines:    list[str] = []
    member_lines:   list[str] = []
    qual_lines:     list[str] = []
    cf_score_lines: list[str] = []
    tag_lines:      list[str] = []
    all_tags:       set[str]  = set()

    radarr_by_name = {qp["name"]: qp for qp in radarr_qps}
    sonarr_by_name = {qp["name"]: qp for qp in sonarr_qps}

    for name in sorted(set(radarr_by_name) | set(sonarr_by_name)):
        in_radarr = name in radarr_by_name
        in_sonarr = name in sonarr_by_name
        base      = radarr_by_name[name] if in_radarr else sonarr_by_name[name]

        # upgrade_score_increment must be >= 1 (schema CHECK constraint)
        score_increment = max(base.get("minUpgradeFormatScore", 1), 1)

        profile_lines.append(
            f"INSERT INTO quality_profiles "
            f"(name, description, upgrades_allowed, minimum_custom_format_score, "
            f"upgrade_until_score, upgrade_score_increment) VALUES ("
            f"{q(name)}, {q('')}, "
            f"{1 if base.get('upgradeAllowed', True) else 0}, "
            f"{base.get('minFormatScore', 0)}, "
            f"{base.get('cutoffFormatScore', 888888)}, "
            f"{score_increment});"
        )

        for tag in profile_tags(name):
            all_tags.add(tag)
            tag_lines.append(
                f"INSERT INTO quality_profile_tags (quality_profile_name, tag_name) "
                f"VALUES ({q(name)}, {q(tag)});"
            )

        cutoff_id = base.get("cutoff", 0)
        position  = 0
        arr       = "radarr" if in_radarr else "sonarr"

        for item in base.get("items", []):
            if "quality" in item:
                raw_name = item["quality"]["name"]
                qname    = normalize_quality_name(raw_name, arr)
                qid      = item["quality"]["id"]
                enabled  = 1 if item.get("allowed", True) else 0
                is_until = 1 if qid == cutoff_id else 0

                qual_lines.append(
                    f"INSERT INTO quality_profile_qualities "
                    f"(quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) "
                    f"VALUES ({q(name)}, {q(qname)}, NULL, {position}, {enabled}, {is_until});"
                )
            else:
                group_name  = item.get("name", f"Group {position}")
                enabled     = 1 if item.get("allowed", True) else 0
                sub_items   = item.get("items", [])
                is_cutoff_g = any(s["quality"]["id"] == cutoff_id for s in sub_items)
                is_until    = 1 if is_cutoff_g else 0

                group_lines.append(
                    f"INSERT INTO quality_groups (quality_profile_name, name) "
                    f"VALUES ({q(name)}, {q(group_name)});"
                )
                qual_lines.append(
                    f"INSERT INTO quality_profile_qualities "
                    f"(quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) "
                    f"VALUES ({q(name)}, NULL, {q(group_name)}, {position}, {enabled}, {is_until});"
                )
                for sub in sub_items:
                    qname = normalize_quality_name(sub["quality"]["name"], arr)
                    member_lines.append(
                        f"INSERT INTO quality_group_members "
                        f"(quality_profile_name, quality_group_name, quality_name) "
                        f"VALUES ({q(name)}, {q(group_name)}, {q(qname)});"
                    )

            position += 1

        r_scores = {e["name"]: e["score"] for e in extract_format_scores(radarr_by_name[name], radarr_cf_map)} if in_radarr else {}
        s_scores = {e["name"]: e["score"] for e in extract_format_scores(sonarr_by_name[name], sonarr_cf_map)} if in_sonarr else {}

        for cf_name in sorted(set(r_scores) | set(s_scores)):
            r = r_scores.get(cf_name)
            s = s_scores.get(cf_name)

            if r is not None and s is not None and r == s:
                rows = [("all", r)]
            elif r is not None and s is not None:
                rows = [("radarr", r), ("sonarr", s)]
            elif r is not None:
                rows = [("radarr", r)]
            else:
                rows = [("sonarr", s)]

            for arr_type, score in rows:
                cf_score_lines.append(
                    f"INSERT INTO quality_profile_custom_formats "
                    f"(quality_profile_name, custom_format_name, arr_type, score) "
                    f"VALUES ({q(name)}, {q(cf_name)}, {q(arr_type)}, {score});"
                )

    qualities_out: list[str] = []
    for header, lines in [
        ("-- Quality Groups",            group_lines),
        ("-- Quality Group Members",     member_lines),
        ("-- Quality Profile Qualities", qual_lines),
    ]:
        if lines:
            qualities_out += [header, ""] + lines + [""]

    tag_inserts = [
        f"INSERT OR IGNORE INTO tags (name) VALUES ({q(t)});"
        for t in sorted(all_tags)
    ]

    return {
        "tags":                      tag_inserts,
        "quality_profiles":          profile_lines,
        "quality_profile_qualities": qualities_out,
        "quality_profile_scores":    cf_score_lines,
        "quality_profile_tags":      tag_lines,
    }

# ─── Media Management ────────────────────────────────────────────────────────

# Radarr API value → schema CHECK value
_COLON_MAP: dict[str, str] = {
    "delete":           "delete",
    "dash":             "dash",
    "spaceDash":        "spaceDash",
    "spaceDashSpace":   "spaceDashSpace",
    "smart":            "smart",
    # older Radarr versions
    "doNotUpgrade":     "doNotUpgradeAutomatically",
}

_PROPERS_MAP: dict[str, str] = {
    "doNotPrefer":               "doNotPrefer",
    "preferAndUpgrade":          "preferAndUpgrade",
    "doNotUpgrade":              "doNotUpgradeAutomatically",
    "doNotUpgradeAutomatically": "doNotUpgradeAutomatically",
}


def build_media_management_sql(
    radarr_naming:    dict | None,
    sonarr_naming:    dict | None,
    radarr_qualdef:   list[dict],
    sonarr_qualdef:   list[dict],
    radarr_mediamgmt: dict | None,
    sonarr_mediamgmt: dict | None,
) -> list[str]:
    lines: list[str] = []

    if radarr_naming:
        colon = _COLON_MAP.get(radarr_naming.get("colonReplacementFormat", "smart"), "smart")
        lines += [
            "-- Radarr Naming", "",
            f"INSERT INTO radarr_naming "
            f"(name, rename, movie_format, movie_folder_format, replace_illegal_characters, colon_replacement_format) "
            f"VALUES ({q('default')}, "
            f"{1 if radarr_naming.get('renameMovies', True) else 0}, "
            f"{q(radarr_naming.get('standardMovieFormat', ''))}, "
            f"{q(radarr_naming.get('movieFolderFormat', ''))}, "
            f"{1 if radarr_naming.get('replaceIllegalCharacters', False) else 0}, "
            f"{q(colon)});",
            "",
        ]

    if sonarr_naming:
        lines += [
            "-- Sonarr Naming", "",
            f"INSERT INTO sonarr_naming "
            f"(name, rename, standard_episode_format, daily_episode_format, anime_episode_format, "
            f"series_folder_format, season_folder_format, replace_illegal_characters, "
            f"colon_replacement_format, custom_colon_replacement_format, multi_episode_style) "
            f"VALUES ({q('default')}, "
            f"{1 if sonarr_naming.get('renameEpisodes', True) else 0}, "
            f"{q(sonarr_naming.get('standardEpisodeFormat', ''))}, "
            f"{q(sonarr_naming.get('dailyEpisodeFormat', ''))}, "
            f"{q(sonarr_naming.get('animeEpisodeFormat', ''))}, "
            f"{q(sonarr_naming.get('seriesFolderFormat', ''))}, "
            f"{q(sonarr_naming.get('seasonFolderFormat', ''))}, "
            f"{1 if sonarr_naming.get('replaceIllegalCharacters', False) else 0}, "
            f"{sonarr_naming.get('colonReplacementFormat', 4)}, "
            f"{q(sonarr_naming.get('customColonReplacementFormat')) if sonarr_naming.get('customColonReplacementFormat') else 'NULL'}, "
            f"{sonarr_naming.get('multiEpisodeStyle', 5)});",
            "",
        ]

    if radarr_qualdef:
        lines += ["-- Radarr Quality Definitions", ""]
        for qd in radarr_qualdef:
            qname = qd.get("quality", {}).get("name", "")
            if not qname:
                continue
            lines.append(
                f"INSERT INTO radarr_quality_definitions (name, quality_name, min_size, max_size, preferred_size) "
                f"VALUES ({q('default')}, {q(qname)}, "
                f"{qd.get('minSize') or 0}, "
                f"{qd.get('maxSize') or 0}, "
                f"{qd.get('preferredSize') or 0});"
            )
        lines.append("")

    if sonarr_qualdef:
        lines += ["-- Sonarr Quality Definitions", ""]
        for qd in sonarr_qualdef:
            qname = qd.get("quality", {}).get("name", "")
            if not qname:
                continue
            lines.append(
                f"INSERT INTO sonarr_quality_definitions (name, quality_name, min_size, max_size, preferred_size) "
                f"VALUES ({q('default')}, {q(qname)}, "
                f"{qd.get('minSize') or 0}, "
                f"{qd.get('maxSize') or 0}, "
                f"{qd.get('preferredSize') or 0});"
            )
        lines.append("")

    if radarr_mediamgmt:
        propers = _PROPERS_MAP.get(radarr_mediamgmt.get("downloadPropersAndRepacks", "doNotPrefer"), "doNotPrefer")
        lines += [
            "-- Radarr Media Settings", "",
            f"INSERT INTO radarr_media_settings (name, propers_repacks, enable_media_info) "
            f"VALUES ({q('default')}, {q(propers)}, "
            f"{1 if radarr_mediamgmt.get('enableMediaInfo', True) else 0});",
            "",
        ]

    if sonarr_mediamgmt:
        propers = _PROPERS_MAP.get(sonarr_mediamgmt.get("downloadPropersAndRepacks", "doNotPrefer"), "doNotPrefer")
        lines += [
            "-- Sonarr Media Settings", "",
            f"INSERT INTO sonarr_media_settings (name, propers_repacks, enable_media_info) "
            f"VALUES ({q('default')}, {q(propers)}, "
            f"{1 if sonarr_mediamgmt.get('enableMediaInfo', True) else 0});",
            "",
        ]

    return lines

# ─── CLI ──────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export Radarr/Sonarr Custom Formats and Quality Profiles to PCD SQL format."
    )

    radarr = parser.add_argument_group("Radarr")
    radarr.add_argument("--radarr-url",     default=os.getenv("RADARR_URL"),     metavar="URL")
    radarr.add_argument("--radarr-api-key", default=os.getenv("RADARR_API_KEY"), metavar="KEY")
    radarr.add_argument("--no-radarr", action="store_true", help="Skip Radarr export")

    sonarr = parser.add_argument_group("Sonarr")
    sonarr.add_argument("--sonarr-url",     default=os.getenv("SONARR_URL"),     metavar="URL")
    sonarr.add_argument("--sonarr-api-key", default=os.getenv("SONARR_API_KEY"), metavar="KEY")
    sonarr.add_argument("--no-sonarr", action="store_true", help="Skip Sonarr export")

    meta = parser.add_argument_group("Database metadata")
    meta.add_argument("--name",        default=os.getenv("DB_NAME",        "my-profilarr-db"))
    meta.add_argument("--description", default=os.getenv("DB_DESCRIPTION", ""))
    meta.add_argument("--author",      default=os.getenv("DB_AUTHOR",      ""))
    meta.add_argument("--repo",        default=os.getenv("DB_REPO",        ""))

    return parser.parse_args()

# ─── Main ─────────────────────────────────────────────────────────────────────

def main() -> None:
    args = parse_args()

    export_radarr = not args.no_radarr and bool(args.radarr_url and args.radarr_api_key)
    export_sonarr = not args.no_sonarr and bool(args.sonarr_url and args.sonarr_api_key)

    if not export_radarr and not export_sonarr:
        print(
            "[ERROR] No source configured. Provide credentials via CLI args or a .env file.\n"
            "        Run with --help for details.",
            file=sys.stderr,
        )
        sys.exit(1)

    out = Path(__file__).resolve().parent.parent
    ops_dir = out / "ops"
    ops_dir.mkdir(parents=True, exist_ok=True)

    radarr_cfs:      list[dict] = []
    sonarr_cfs:      list[dict] = []
    radarr_qps:      list[dict] = []
    sonarr_qps:      list[dict] = []
    radarr_naming:   dict | None = None
    sonarr_naming:   dict | None = None
    radarr_qualdef:  list[dict] = []
    sonarr_qualdef:  list[dict] = []
    radarr_mediamgmt: dict | None = None
    sonarr_mediamgmt: dict | None = None

    if export_radarr:
        print("Fetching Radarr Custom Formats...")
        radarr_cfs = api_get(args.radarr_url, args.radarr_api_key, "customformat")
        print(f"  {len(radarr_cfs)} found.")

    if export_sonarr:
        print("Fetching Sonarr Custom Formats...")
        sonarr_cfs = api_get(args.sonarr_url, args.sonarr_api_key, "customformat")
        print(f"  {len(sonarr_cfs)} found.")

    # Deduplicate: track source per CF name; radarr wins on conflict
    cf_source: dict[str, str] = {}
    cf_by_name: dict[str, dict] = {}

    for cf in sonarr_cfs:
        cf_by_name[cf["name"]] = cf
        cf_source[cf["name"]] = "sonarr"
    for cf in radarr_cfs:
        if cf["name"] in cf_by_name:
            cf_source[cf["name"]] = "all"
        else:
            cf_source[cf["name"]] = "radarr"
        cf_by_name[cf["name"]] = cf

    print(f"\n{len(cf_by_name)} unique custom formats.")

    if export_radarr:
        print("\nFetching Radarr Quality Profiles...")
        radarr_qps = api_get(args.radarr_url, args.radarr_api_key, "qualityprofile")
        print(f"  {len(radarr_qps)} found.")

    if export_sonarr:
        print("\nFetching Sonarr Quality Profiles...")
        sonarr_qps = api_get(args.sonarr_url, args.sonarr_api_key, "qualityprofile")
        print(f"  {len(sonarr_qps)} found.")

    if export_radarr:
        print("\nFetching Radarr Media Management...")
        radarr_naming    = api_get(args.radarr_url, args.radarr_api_key, "config/naming")
        radarr_qualdef   = api_get(args.radarr_url, args.radarr_api_key, "qualitydefinition")
        radarr_mediamgmt = api_get(args.radarr_url, args.radarr_api_key, "config/mediamanagement")
        print("  Done.")

    if export_sonarr:
        print("\nFetching Sonarr Media Management...")
        sonarr_naming    = api_get(args.sonarr_url, args.sonarr_api_key, "config/naming")
        sonarr_qualdef   = api_get(args.sonarr_url, args.sonarr_api_key, "qualitydefinition")
        sonarr_mediamgmt = api_get(args.sonarr_url, args.sonarr_api_key, "config/mediamanagement")
        print("  Done.")

    radarr_cf_map: dict[int, str] = {cf["id"]: cf["name"] for cf in radarr_cfs}
    sonarr_cf_map: dict[int, str] = {cf["id"]: cf["name"] for cf in sonarr_cfs}
    total_profiles = len(set(qp["name"] for qp in radarr_qps + sonarr_qps))
    print(f"\n{total_profiles} unique quality profiles.")

    # Build SQL — one file per table group
    cf_sections = build_custom_formats_sql(cf_by_name, cf_source)
    qp_sections = build_quality_profiles_sql(radarr_qps, sonarr_qps, radarr_cf_map, sonarr_cf_map)
    mm_lines    = build_media_management_sql(
        radarr_naming, sonarr_naming,
        radarr_qualdef, sonarr_qualdef,
        radarr_mediamgmt, sonarr_mediamgmt,
    )

    files: list[tuple[str, list[str]]] = [
        ("1.regular_expressions.sql",       cf_sections["regular_expressions"]),
        ("2.custom_formats.sql",            cf_sections["custom_formats"]),
        ("3.custom_format_conditions.sql",  cf_sections["custom_format_conditions"]),
        ("4.tags.sql",                      qp_sections["tags"]),
        ("5.quality_profiles.sql",          qp_sections["quality_profiles"]),
        ("6.quality_profile_qualities.sql", qp_sections["quality_profile_qualities"]),
        ("7.quality_profile_scores.sql",    qp_sections["quality_profile_scores"]),
        ("8.quality_profile_tags.sql",      qp_sections["quality_profile_tags"]),
        ("9.media_management.sql",          mm_lines),
    ]

    print()
    for filename, lines in files:
        path = ops_dir / filename
        path.write_text("-- Generated by import.py\n\n" + "\n".join(lines), encoding="utf-8")
        print(f"Wrote {path}  ({len(lines)} lines)")

    # Remove old combined files if present
    current_files = {f for f, _ in files}
    for old_name in (
        "1.initial.sql", "1.custom_formats.sql", "2.quality_profiles.sql",
        "4.quality_profiles.sql", "5.quality_profile_qualities.sql", "6.quality_profile_scores.sql",
    ):
        old = ops_dir / old_name
        if old.exists() and old_name not in current_files:
            old.unlink()
            print(f"Removed {old}")

    # Update pcd.json
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
        "dependencies": {
            "https://github.com/Dictionarry-Hub/schema": "1.1.0",
        },
        "profilarr": {
            "minimum_version": "2.0.0",
        },
    }
    if args.author:
        manifest["authors"] = [{"name": args.author}]
    if args.repo:
        manifest["repository"] = args.repo

    manifest_path = out / "pcd.json"
    manifest_path.write_text(json.dumps(manifest, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {manifest_path}")

    print(f"""
Done! Next steps:
  1. git add ops/ pcd.json && git commit -m "update export"
  2. Push to GitHub/Gitea
  3. In Profilarr: Settings → Database → Add Remote Repo

Note: The old custom_formats/ profiles/ etc. directories are no
longer used and can be deleted.
""")


if __name__ == "__main__":
    main()
