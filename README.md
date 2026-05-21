# wirehack7's Profilarr Database

A personal [Profilarr](https://github.com/Dictionarry-Hub/profilarr) database with German-focused custom formats and quality profiles for Radarr and Sonarr.

## Usage

1. Profilarr → **Settings → Database → Add Remote Repo**
2. URL: `https://github.com/wirehack7/profilarr-db`

---

## Quality Profiles

### German Profiles

| Profile | Upgrades | Upgrade Until | Until Score | German DL | German Only | Not ENG/GER |
|---|:---:|---|:---:|:---:|:---:|:---:|
| German 480p | yes | Bluray-480p | 50 000 | +25 000 | +15 000 | -30 000 |
| German 720p | yes | Bluray-720p | 50 000 | +25 000 | +15 000 | -30 000 |
| German 1080p | yes | Bluray-1080p | 50 000 | +25 000 | +15 000 | -30 000 |
| German 4K | yes | Bluray-2160p | 50 000 | +25 000 | +15 000 | -30 000 |

### Standard Profiles

| Profile | Upgrades | Upgrade Until | Max Quality Range |
|---|:---:|---|---|
| SD | no | Bluray-480p | up to 480p/576p |
| HD-720p | no | Bluray-720p | 720p only |
| HD-1080p | no | Bluray-1080p | 1080p only |
| HD - 720p/1080p | no | Bluray-720p | 720p–1080p |
| Ultra-HD | no | Remux-2160p | 2160p only |
| Any | no | Bluray-480p | all qualities |

---

## Custom Formats

| Format | Purpose |
|---|---|
| German DL | Detects German dual-language releases |
| German DL 2 | Alternative German DL pattern |
| Language: German Only | Prefers German-only audio |
| Language: Not ENG/GER | Penalizes releases without English or German |

---

## Export Script

The `scripts/import.py` script exports Custom Formats, Quality Profiles, and Media Management settings from Radarr and Sonarr and writes them as PCD-compliant SQL files under `ops/`.

### Setup

```bash
pip install -r scripts/requirements.txt
```

Create a `.env` file in the repo root (already in `.gitignore`):

```env
RADARR_URL=https://your-radarr/
RADARR_API_KEY=your_key

SONARR_URL=https://your-sonarr/
SONARR_API_KEY=your_key

DB_NAME=my-profilarr-db
DB_DESCRIPTION=My export
DB_AUTHOR=yourname
DB_REPO=https://github.com/yourname/profilarr-db
```

### Run

```bash
python scripts/import.py
```

Or pass everything via CLI (overrides `.env`):

```bash
python scripts/import.py \
  --radarr-url https://radarr.example.com --radarr-api-key abc123 \
  --sonarr-url https://sonarr.example.com --sonarr-api-key def456 \
  --name my-db --description "My export" --author myname
```

Skip one source with `--no-radarr` or `--no-sonarr`.

### Generated files

| File | Content |
|---|---|
| `ops/1.regular_expressions.sql` | Regex patterns for conditions |
| `ops/2.custom_formats.sql` | Custom format definitions |
| `ops/3.custom_format_conditions.sql` | All condition types |
| `ops/4.tags.sql` | Tags derived from profile names |
| `ops/5.quality_profiles.sql` | Profile metadata |
| `ops/6.quality_profile_qualities.sql` | Groups, members, quality order |
| `ops/7.quality_profile_scores.sql` | Custom format scores per profile |
| `ops/8.quality_profile_tags.sql` | Profile tag assignments |
| `ops/9.media_management.sql` | Naming, quality definitions, media settings |
