-- @operation: export
-- @entity: batch
-- @name: reject iso / dvd disc images
-- @exportedAt: 2026-11-21T00:00:00.000Z

-- Unwanted: ISO (score -100000, minimum score 0 => always rejected)
--   Disc images that cannot be played or imported as a normal video file:
--   ISO / IMG images (also Blu-ray / UHD ISO) and DVD images (DVDR, DVD-R,
--   DVD5, DVD9, PAL/NTSC DVD). Sonarr has no DVD-R quality and parses DVD
--   images as plain DVD, which is enabled in every profile.
--   "ISO" / "IMG" only match in upper case (release tag), so titles such as
--   "The Iso ..." or "Isolation" are not hit. Encodes (x264/x265, REMUX, MKV,
--   BDRip, DVDRip) are never matched. Full Blu-ray folders (BDMV, BD50 ...)
--   are already covered by "Unwanted: BR-DISK".

-- --- Cleanup (idempotency)

delete from "quality_profile_custom_formats" where "custom_format_name" = 'Unwanted: ISO';
delete from "condition_patterns" where "custom_format_name" = 'Unwanted: ISO';
delete from "custom_format_conditions" where "custom_format_name" = 'Unwanted: ISO';
delete from "custom_format_tags" where "custom_format_name" = 'Unwanted: ISO';
delete from "custom_formats" where "name" = 'Unwanted: ISO';
delete from "regular_expressions" where "name" = 'Unwanted: ISO :: ISO';

-- --- Regular expression

INSERT INTO regular_expressions (name, pattern) VALUES ('Unwanted: ISO :: ISO', '(?i)^(?!.*\b([xh][-_. ]?26[45]|REMUX|MKV|BDRip|DVDRip)\b).*(\b((?-i:ISO|IMG)|DVD[-_. ]?R|DVD[-_. ]?[59]|(PAL|NTSC)[-_. ]+DVD)\b|\.(iso|img)$)');

-- --- Custom format

INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Unwanted: ISO', 'Rejects disc images (ISO, IMG, DVDR, DVD5/DVD9)', 0);

-- --- Condition

INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Unwanted: ISO', 'ISO', 'release_title', 'all', 0, 1);
INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('Unwanted: ISO', 'ISO', 'Unwanted: ISO :: ISO');

-- --- Scores

INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Unwanted: ISO', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Unwanted: ISO', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Unwanted: ISO', 'all', -100000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Unwanted: ISO', 'all', -100000);
