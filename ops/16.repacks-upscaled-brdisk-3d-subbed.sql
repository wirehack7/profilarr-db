-- @operation: export
-- @entity: batch
-- @name: repacks, upscaled, br-disk, 3d, german subbed
-- @exportedAt: 2026-11-15T00:00:00.000Z

-- 1. Repack/Proper (+5 / +6 / +7)
--    Propers/Repacks are set to "Do not prefer" in media management, so the
--    custom format score alone decides. Without these formats a REPACK, PROPER
--    or RERiP had the same score as the broken release and was never grabbed.
--    Upgrade Until Score is raised by 7 so a repack still upgrades a release
--    that already reached the cutoff.
--
-- 2. Unwanted (score -100000, minimum score 0 => always rejected)
--    Upscaled   Upscaled / AI-upscaled / UpsUHD fake 4K (would get +3000 as 2160p)
--    BR-DISK    Full Blu-ray disc images. Sonarr has no BR-DISK quality and
--               parses them as Bluray-2160p/1080p. Encodes (x264/x265, REMUX,
--               MKV, BDRip) are never matched.
--    3D         3D.HSBS etc. parse as normal Bluray-1080p.
--
-- 3. German Subbed as fallback
--    Original audio with German subtitles (German.Subbed, GerSub) is parsed as
--    German and scored like a German dub. "Language: German Only" and
--    "German DL 2" now require the title NOT to be subbed, so these releases
--    score 0 like English. "Language: Not ENG/GER" ignores titles containing
--    "German", so they are not rejected either.

-- --- Cleanup (idempotency)

delete from "quality_profile_custom_formats" where "custom_format_name" in ('Repack/Proper', 'Repack v2', 'Repack v3', 'Unwanted: Upscaled', 'Unwanted: BR-DISK', 'Unwanted: 3D');
delete from "condition_patterns" where "custom_format_name" in ('Repack/Proper', 'Repack v2', 'Repack v3', 'Unwanted: Upscaled', 'Unwanted: BR-DISK', 'Unwanted: 3D');
delete from "custom_format_conditions" where "custom_format_name" in ('Repack/Proper', 'Repack v2', 'Repack v3', 'Unwanted: Upscaled', 'Unwanted: BR-DISK', 'Unwanted: 3D');
delete from "custom_format_tags" where "custom_format_name" in ('Repack/Proper', 'Repack v2', 'Repack v3', 'Unwanted: Upscaled', 'Unwanted: BR-DISK', 'Unwanted: 3D');
delete from "custom_formats" where "name" in ('Repack/Proper', 'Repack v2', 'Repack v3', 'Unwanted: Upscaled', 'Unwanted: BR-DISK', 'Unwanted: 3D');
delete from "condition_patterns" where "custom_format_name" in ('Language: German Only', 'German DL 2') and "condition_name" = 'Not Subbed';
delete from "custom_format_conditions" where "custom_format_name" in ('Language: German Only', 'German DL 2') and "name" = 'Not Subbed';
delete from "regular_expressions" where "name" in ('Repack/Proper :: Repack/Proper', 'Repack v2 :: Repack v2', 'Repack v3 :: Repack v3', 'Unwanted: Upscaled :: Upscaled', 'Unwanted: BR-DISK :: BR-DISK', 'Unwanted: 3D :: 3D', 'Language: German Only :: Not Subbed', 'German DL 2 :: Not Subbed');

-- --- Regular expressions

INSERT INTO regular_expressions (name, pattern) VALUES ('Repack/Proper :: Repack/Proper', '(?i)\b(REPACK|PROPER|RERIP)\b');
INSERT INTO regular_expressions (name, pattern) VALUES ('Repack v2 :: Repack v2', '(?i)\b(REPACK2|PROPER2|RERIP2)\b');
INSERT INTO regular_expressions (name, pattern) VALUES ('Repack v3 :: Repack v3', '(?i)\b(REPACK3|PROPER3|RERIP3)\b');
INSERT INTO regular_expressions (name, pattern) VALUES ('Unwanted: Upscaled :: Upscaled', '(?i)\b((AI[-_. ]?)?Upscal(e|ed|ing)|Ups[-_. ]?UHD)\b');
INSERT INTO regular_expressions (name, pattern) VALUES ('Unwanted: BR-DISK :: BR-DISK', '(?i)^(?!.*\b([xh][-_. ]?26[45]|REMUX|MKV|BDRip)\b).*\b(COMPLETE[-_. ]+(UHD[-_. ]+)?(BLU[-_. ]?RAY|BD)|BDMV|BR[-_. ]?DISK|(BD|UHD)[-_. ]?(25|50|66|100)|Full[-_. ]?Blu[-_. ]?ray)\b');
INSERT INTO regular_expressions (name, pattern) VALUES ('Unwanted: 3D :: 3D', '(?i)\b(3D|H?SBS|HOU|Half[-_. ]?(SBS|OU))\b');
INSERT INTO regular_expressions (name, pattern) VALUES ('Language: German Only :: Not Subbed', '(?i)\b(Subbed|Ger(man)?[-_. ]?Subs?)\b');
INSERT INTO regular_expressions (name, pattern) VALUES ('German DL 2 :: Not Subbed', '(?i)\b(Subbed|Ger(man)?[-_. ]?Subs?)\b');

-- --- Custom formats

INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Repack/Proper', 'Prefers fixed re-releases (REPACK, PROPER, RERiP)', 0);
INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Repack v2', 'Second fix re-release (REPACK2, PROPER2, RERiP2)', 0);
INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Repack v3', 'Third fix re-release (REPACK3, PROPER3, RERiP3)', 0);
INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Unwanted: Upscaled', 'Rejects upscaled fake 4K (Upscaled, AI Upscale, UpsUHD)', 0);
INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Unwanted: BR-DISK', 'Rejects full Blu-ray disc images (COMPLETE BLURAY, BDMV, BD50/66)', 0);
INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Unwanted: 3D', 'Rejects 3D releases (3D, SBS, HSBS, HOU)', 0);

-- --- Conditions

INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Repack/Proper', 'Repack/Proper', 'release_title', 'all', 0, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Repack v2', 'Repack v2', 'release_title', 'all', 0, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Repack v3', 'Repack v3', 'release_title', 'all', 0, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Unwanted: Upscaled', 'Upscaled', 'release_title', 'all', 0, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Unwanted: BR-DISK', 'BR-DISK', 'release_title', 'all', 0, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Unwanted: 3D', '3D', 'release_title', 'all', 0, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Language: German Only', 'Not Subbed', 'release_title', 'all', 1, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('German DL 2', 'Not Subbed', 'release_title', 'all', 1, 1);

INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('Repack/Proper', 'Repack/Proper', 'Repack/Proper :: Repack/Proper');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('Repack v2', 'Repack v2', 'Repack v2 :: Repack v2');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('Repack v3', 'Repack v3', 'Repack v3 :: Repack v3');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('Unwanted: Upscaled', 'Upscaled', 'Unwanted: Upscaled :: Upscaled');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('Unwanted: BR-DISK', 'BR-DISK', 'Unwanted: BR-DISK :: BR-DISK');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('Unwanted: 3D', '3D', 'Unwanted: 3D :: 3D');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('Language: German Only', 'Not Subbed', 'Language: German Only :: Not Subbed');
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('German DL 2', 'Not Subbed', 'German DL 2 :: Not Subbed');

-- --- Scores

INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Repack/Proper', 'all', 5);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Repack v2', 'all', 6);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Repack v3', 'all', 7);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Unwanted: Upscaled', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Unwanted: BR-DISK', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Unwanted: 3D', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Repack/Proper', 'all', 5);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Repack v2', 'all', 6);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Repack v3', 'all', 7);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Unwanted: Upscaled', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Unwanted: BR-DISK', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Unwanted: 3D', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Repack/Proper', 'all', 5);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Repack v2', 'all', 6);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Repack v3', 'all', 7);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Unwanted: Upscaled', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Unwanted: BR-DISK', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Unwanted: 3D', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Repack/Proper', 'all', 5);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Repack v2', 'all', 6);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Repack v3', 'all', 7);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Unwanted: Upscaled', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Unwanted: BR-DISK', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Unwanted: 3D', 'all', -100000);

update "quality_profiles" set "upgrade_until_score" = 25307 where "name" = 'German 480p';
update "quality_profiles" set "upgrade_until_score" = 26307 where "name" = 'German 720p';
update "quality_profiles" set "upgrade_until_score" = 27307 where "name" = 'German 1080p';
update "quality_profiles" set "upgrade_until_score" = 28807 where "name" = 'German 4K';
