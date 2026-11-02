# wirehack7's Profilarr Database

A personal [Profilarr](https://github.com/Dictionarry-Hub/profilarr) database with German-focused custom formats and quality profiles for Radarr and Sonarr.

## Usage

1. Profilarr → **Settings → Database → Add Remote Repo**
2. URL: `https://github.com/wirehack7/profilarr-db`

---

## Quality Profiles

### German Profiles

German is always preferred over English, regardless of quality. English is only grabbed as a fallback and gets replaced as soon as a German release shows up.

| Profile | Allowed qualities | Upgrade Until Score |
|---|---|:---:|
| German 480p | DVD, WEB/Bluray 480p | 25 300 |
| German 720p | up to 720p | 26 300 |
| German 1080p | up to 1080p | 27 300 |
| German 4K | up to 2160p | 28 300 |

#### Why one merged quality group?

Radarr and Sonarr compare **quality first** and use the custom format score only as a tie-breaker within the same quality. They also accept every quality upgrade regardless of score. With a classic quality ladder an English WEB-1080p beats a German HDTV-720p, and an English Bluray-1080p replaces an existing German DL WEB-1080p.

Each profile therefore has a single quality group containing all allowed qualities, so the score alone decides. The former quality order is rebuilt with small resolution and source scores that can never bridge a language tier:

| Custom Format | Score |
|---|:---:|
| German DL / German DL 2 | +25 000 |
| Language: German Only | +15 000 |
| *(English, no language CF)* | 0 |
| Language: Not ENG/GER | -30 000 *(rejected, minimum score 0)* |
| Resolution: 720p / 1080p / 2160p | +1 000 / +2 000 / +3 000 |
| Source: HDTV / WEB / Bluray | +100 / +200 / +300 |

The default delay profile lets releases scoring at least 15 000 (= German) bypass the delay; everything else waits 6 hours.

---

## Custom Formats

| Format | Purpose |
|---|---|
| German DL | Detects German dual-language releases |
| German DL 2 | Alternative German DL pattern |
| Language: German Only | Prefers German-only audio |
| Language: Not ENG/GER | Penalizes releases without English or German |
| Resolution: 720p / 1080p / 2160p | Resolution ranking inside the merged quality group |
| Source: HDTV / WEB / Bluray | Source ranking inside the merged quality group |

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

`ops/11.*` and later are hand-written changes applied on top of the export.
