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
| German 480p | yes | Bluray-480p | 5 000 | +25 000 | +15 000 | -30 000 |
| German 720p | yes | Bluray-720p | 50 000 | +25–50 000 ¹ | +15 000 | -30 000 |
| German 1080p | yes | Bluray-1080p | 50 000 | +25 000 | +15 000 | -30 000 |
| German 4K | yes | Bluray-2160p | 50 000 | +25 000 | +15 000 | -30 000 |

> ¹ German 720p: Radarr scores German DL / DL 2 at **+50 000**, Sonarr at **+25 000**

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
