-- @operation: export
-- @entity: batch
-- @name: unwanted releases and HDR
-- @exportedAt: 2026-11-07T00:00:00.000Z

-- 1. Unwanted releases (score -100000, minimum score 0 => always rejected)
--
--   Unwanted: CAM/TS       CAM, HDCAM, TS, HDTS, TELESYNC, TC, TELECINE in the title.
--                          Radarr already disables these qualities, but Sonarr has
--                          no CAM/TELESYNC quality, and German releases like
--                          "German.MD.TS" can parse as a normal quality.
--   Unwanted: Line/Mic     German audio recorded in the cinema or from the line
--                          feed (MD, LD, AC3MD, AC3LD, LiNE, MiC, Line.Dubbed,
--                          Mic.Dubbed). These are usually muxed onto a clean WEB or
--                          BluRay video and would otherwise score as German DL.
--   Unwanted: Ext. Audio   German audio taken from another source and synced in
--                          (AC3D, DTSD, EAC3D, DDP51D ...; "Dubbed" for Radarr
--                          only, because German anime uses "Dubbed" for a
--                          normal German dub).
--
-- 2. HDR in German 4K
--
--   HDR                    +500  HDR10, HDR10+, HLG, DV: preferred over SDR
--   DV (w/o HDR fallback)  -1000 Dolby Vision without HDR10 base layer shows
--                                wrong colors on non-DV players; SDR is preferred.
--
--   The bonus stays far below the 10000 gap between language tiers, so it never
--   overrides language. Upgrade Until Score for German 4K is raised by 500.
--
-- 3. German 4K: Bluray-720p was disabled while WEB-720p was allowed; added.

-- --- Cleanup (idempotency)

delete from "quality_profile_custom_formats" where "custom_format_name" in ('Unwanted: CAM/TS', 'Unwanted: Line/Mic Dubbed', 'Unwanted: External Audio', 'HDR', 'DV (w/o HDR fallback)');
delete from "condition_patterns" where "custom_format_name" in ('Unwanted: CAM/TS', 'Unwanted: Line/Mic Dubbed', 'Unwanted: External Audio', 'HDR', 'DV (w/o HDR fallback)');
delete from "custom_format_conditions" where "custom_format_name" in ('Unwanted: CAM/TS', 'Unwanted: Line/Mic Dubbed', 'Unwanted: External Audio', 'HDR', 'DV (w/o HDR fallback)');
delete from "custom_format_tags" where "custom_format_name" in ('Unwanted: CAM/TS', 'Unwanted: Line/Mic Dubbed', 'Unwanted: External Audio', 'HDR', 'DV (w/o HDR fallback)');
delete from "custom_formats" where "name" in ('Unwanted: CAM/TS', 'Unwanted: Line/Mic Dubbed', 'Unwanted: External Audio', 'HDR', 'DV (w/o HDR fallback)');
delete from "regular_expressions" where "name" in ('Unwanted: CAM/TS :: CAM/TS', 'Unwanted: Line/Mic Dubbed :: Line/Mic', 'Unwanted: External Audio :: Dubbed', 'Unwanted: External Audio :: Codec D', 'HDR :: HDR', 'DV (w/o HDR fallback) :: DV', 'DV (w/o HDR fallback) :: HDR fallback');

-- --- Regular expressions

INSERT INTO regular_expressions (name, pattern) VALUES ('Unwanted: CAM/TS :: CAM/TS', '(?i)\b(CAM|HDCAM|CAMRip|TS|HDTS|TSRip|TELESYNC|PDVD|TC|HDTC|TELECINE)\b');
INSERT INTO regular_expressions (name, pattern) VALUES ('Unwanted: Line/Mic Dubbed :: Line/Mic', '(?i)(?<=\bGerman\b.*)\b((AC3|EAC3|DTS|DD|DDP)?(MD|LD)|LINE|MiC|(Line|Mic)[-_. ]?Dubbed)\b');
INSERT INTO regular_expressions (name, pattern) VALUES ('Unwanted: External Audio :: Dubbed', '(?i)(?<=\bGerman\b.*)\bDUBBED\b');
INSERT INTO regular_expressions (name, pattern) VALUES ('Unwanted: External Audio :: Codec D', '(?i)(?<=\bGerman\b.*)\b(AC3|EAC3|DTS|DTSHD|DTSMA|DTSX|DD|DDP|DD51|DDP51|DD71|DDP71|TrueHD|Atmos)D\b');
INSERT INTO regular_expressions (name, pattern) VALUES ('HDR :: HDR', '(?i)\b(HDR(10)?|HDR10P(lus)?|HLG|PQ10|DV|DoVi|Dolby[-_. ]?Vision)\b');
INSERT INTO regular_expressions (name, pattern) VALUES ('DV (w/o HDR fallback) :: DV', '(?i)\b(DV|DoVi|Dolby[-_. ]?Vision)\b');
INSERT INTO regular_expressions (name, pattern) VALUES ('DV (w/o HDR fallback) :: HDR fallback', '(?i)\b(HDR(10)?|HDR10P(lus)?|HLG|PQ10)\b');

-- --- Custom formats

INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Unwanted: CAM/TS', 'Rejects CAM, Telesync and Telecine releases', 0);
INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Unwanted: Line/Mic Dubbed', 'Rejects German audio recorded in the cinema or from the line feed (MD, LD, LiNE)', 0);
INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Unwanted: External Audio', 'Rejects German audio added from another source (Dubbed, AC3D, DTSD ...)', 0);
INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('HDR', 'HDR10, HDR10+, HLG or Dolby Vision', 0);
INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('DV (w/o HDR fallback)', 'Dolby Vision without HDR10 base layer', 0);

-- --- Conditions

INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Unwanted: CAM/TS', 'CAM/TS', 'release_title', 'all', 0, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Unwanted: Line/Mic Dubbed', 'Line/Mic', 'release_title', 'all', 0, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Unwanted: External Audio', 'Dubbed', 'release_title', 'radarr', 0, 0);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Unwanted: External Audio', 'Codec D', 'release_title', 'all', 0, 0);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('HDR', 'HDR', 'release_title', 'all', 0, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('DV (w/o HDR fallback)', 'DV', 'release_title', 'all', 0, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('DV (w/o HDR fallback)', 'HDR fallback', 'release_title', 'all', 1, 1);

INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('Unwanted: CAM/TS', 'CAM/TS', 'Unwanted: CAM/TS :: CAM/TS');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('Unwanted: Line/Mic Dubbed', 'Line/Mic', 'Unwanted: Line/Mic Dubbed :: Line/Mic');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('Unwanted: External Audio', 'Dubbed', 'Unwanted: External Audio :: Dubbed');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('Unwanted: External Audio', 'Codec D', 'Unwanted: External Audio :: Codec D');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('HDR', 'HDR', 'HDR :: HDR');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('DV (w/o HDR fallback)', 'DV', 'DV (w/o HDR fallback) :: DV');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('DV (w/o HDR fallback)', 'HDR fallback', 'DV (w/o HDR fallback) :: HDR fallback');

-- --- Scores

INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Unwanted: CAM/TS', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Unwanted: Line/Mic Dubbed', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Unwanted: External Audio', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Unwanted: CAM/TS', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Unwanted: Line/Mic Dubbed', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Unwanted: External Audio', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Unwanted: CAM/TS', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Unwanted: Line/Mic Dubbed', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Unwanted: External Audio', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Unwanted: CAM/TS', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Unwanted: Line/Mic Dubbed', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Unwanted: External Audio', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'HDR', 'all', 500);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'DV (w/o HDR fallback)', 'all', -1000);

update "quality_profiles" set "upgrade_until_score" = 28800 where "name" = 'German 4K';

-- --- German 4K: allow Bluray-720p like WEB-720p

delete from "quality_profile_qualities" where "quality_profile_name" = 'German 4K' and "quality_name" = 'Bluray-720p';
delete from "quality_group_members" where "quality_profile_name" = 'German 4K' and "quality_name" = 'Bluray-720p';
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'Bluray-720p', 15);
