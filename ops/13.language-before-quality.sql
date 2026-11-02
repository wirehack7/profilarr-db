-- @operation: export
-- @entity: batch
-- @name: language before quality
-- @exportedAt: 2026-11-02T00:00:00.000Z

-- Radarr/Sonarr rank releases by quality FIRST and only use the custom format
-- score as a tie-breaker inside the same quality. They also accept any quality
-- upgrade regardless of score. With a classic quality ladder an English
-- Bluray-1080p therefore beats (and replaces) a German DL WEB-1080p.
--
-- Fix: every profile gets a single quality group containing all allowed
-- qualities, so the custom format score alone decides. The former quality
-- order is rebuilt with small resolution/source scores that can never bridge
-- the gap between language tiers:
--
--   German DL        +25000
--   German only      +15000
--   English              0   (fallback)
--   Not ENG/GER      -30000   (rejected, min score 0)
--   resolution       +0 / +1000 (720p) / +2000 (1080p) / +3000 (2160p)
--   source           +0 (DVD) / +100 (HDTV) / +200 (WEB) / +300 (Bluray)
--
-- Every section deletes before inserting, so this op stays valid on top of a
-- fresh scripts/import.py export that already contains these entities.

-- --- Cleanup (idempotency)

delete from "quality_profile_custom_formats" where "custom_format_name" in ('Resolution: 720p', 'Resolution: 1080p', 'Resolution: 2160p', 'Source: HDTV', 'Source: WEB', 'Source: Bluray');
delete from "condition_resolutions" where "custom_format_name" in ('Resolution: 720p', 'Resolution: 1080p', 'Resolution: 2160p');
delete from "condition_sources" where "custom_format_name" in ('Source: HDTV', 'Source: WEB', 'Source: Bluray');
delete from "custom_format_conditions" where "custom_format_name" in ('Resolution: 720p', 'Resolution: 1080p', 'Resolution: 2160p', 'Source: HDTV', 'Source: WEB', 'Source: Bluray');
delete from "custom_format_tags" where "custom_format_name" in ('Resolution: 720p', 'Resolution: 1080p', 'Resolution: 2160p', 'Source: HDTV', 'Source: WEB', 'Source: Bluray');
delete from "custom_formats" where "name" in ('Resolution: 720p', 'Resolution: 1080p', 'Resolution: 2160p', 'Source: HDTV', 'Source: WEB', 'Source: Bluray');

-- --- Custom formats: resolution

INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Resolution: 720p', 'Quality ranking inside merged quality group', 0);
INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Resolution: 1080p', 'Quality ranking inside merged quality group', 0);
INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Resolution: 2160p', 'Quality ranking inside merged quality group', 0);

INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Resolution: 720p', '720p', 'resolution', 'all', 0, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Resolution: 1080p', '1080p', 'resolution', 'all', 0, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Resolution: 2160p', '2160p', 'resolution', 'all', 0, 1);

INSERT INTO condition_resolutions (custom_format_name, condition_name, resolution) VALUES ('Resolution: 720p', '720p', '720p');
INSERT INTO condition_resolutions (custom_format_name, condition_name, resolution) VALUES ('Resolution: 1080p', '1080p', '1080p');
INSERT INTO condition_resolutions (custom_format_name, condition_name, resolution) VALUES ('Resolution: 2160p', '2160p', '2160p');

-- --- Custom formats: source

INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Source: HDTV', 'Quality ranking inside merged quality group', 0);
INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Source: WEB', 'Quality ranking inside merged quality group', 0);
INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Source: Bluray', 'Quality ranking inside merged quality group', 0);

INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Source: HDTV', 'Television', 'source', 'all', 0, 1);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Source: WEB', 'WEB-DL', 'source', 'all', 0, 0);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Source: WEB', 'WEBRip', 'source', 'all', 0, 0);
INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Source: Bluray', 'Bluray', 'source', 'all', 0, 1);

INSERT INTO condition_sources (custom_format_name, condition_name, source) VALUES ('Source: HDTV', 'Television', 'television');
INSERT INTO condition_sources (custom_format_name, condition_name, source) VALUES ('Source: WEB', 'WEB-DL', 'web_dl');
INSERT INTO condition_sources (custom_format_name, condition_name, source) VALUES ('Source: WEB', 'WEBRip', 'webrip');
INSERT INTO condition_sources (custom_format_name, condition_name, source) VALUES ('Source: Bluray', 'Bluray', 'bluray');

-- --- Scores

INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Resolution: 720p', 'all', 1000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Resolution: 1080p', 'all', 2000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Resolution: 2160p', 'all', 3000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Source: HDTV', 'all', 100);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Source: WEB', 'all', 200);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Source: Bluray', 'all', 300);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Resolution: 720p', 'all', 1000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Resolution: 1080p', 'all', 2000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Resolution: 2160p', 'all', 3000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Source: HDTV', 'all', 100);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Source: WEB', 'all', 200);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Source: Bluray', 'all', 300);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Resolution: 720p', 'all', 1000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Resolution: 1080p', 'all', 2000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Resolution: 2160p', 'all', 3000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Source: HDTV', 'all', 100);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Source: WEB', 'all', 200);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Source: Bluray', 'all', 300);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Resolution: 720p', 'all', 1000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Resolution: 1080p', 'all', 2000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Resolution: 2160p', 'all', 3000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Source: HDTV', 'all', 100);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Source: WEB', 'all', 200);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Source: Bluray', 'all', 300);

-- --- Quality groups: one merged group per profile, cutoff = group

-- German 480p: 4 enabled qualities merged into 'Up to 480p'
delete from "quality_group_members" where "quality_profile_name" = 'German 480p';
delete from "quality_profile_qualities" where "quality_profile_name" = 'German 480p';
delete from "quality_groups" where "quality_profile_name" = 'German 480p';
INSERT INTO quality_groups (quality_profile_name, name) VALUES ('German 480p', 'Up to 480p');
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 480p', 'Up to 480p', 'Bluray-480p', 0);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 480p', 'Up to 480p', 'WEBDL-480p', 1);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 480p', 'Up to 480p', 'WEBRip-480p', 2);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 480p', 'Up to 480p', 'DVD', 3);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', NULL, 'Up to 480p', 0, 1, 1);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'Raw-HD', NULL, 1, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'BR-DISK', NULL, 2, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'Remux-2160p', NULL, 3, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'Bluray-2160p', NULL, 4, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'WEBDL-2160p', NULL, 5, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'WEBRip-2160p', NULL, 6, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'HDTV-2160p', NULL, 7, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'Remux-1080p', NULL, 8, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'Bluray-1080p', NULL, 9, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'WEBDL-1080p', NULL, 10, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'WEBRip-1080p', NULL, 11, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'HDTV-1080p', NULL, 12, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'Bluray-720p', NULL, 13, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'WEBDL-720p', NULL, 14, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'WEBRip-720p', NULL, 15, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'HDTV-720p', NULL, 16, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'Bluray-576p', NULL, 17, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'DVD-R', NULL, 18, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'SDTV', NULL, 19, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'DVDSCR', NULL, 20, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'REGIONAL', NULL, 21, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'TELECINE', NULL, 22, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'TELESYNC', NULL, 23, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'CAM', NULL, 24, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'WORKPRINT', NULL, 25, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 480p', 'Unknown', NULL, 26, 0, 0);
update "quality_profiles" set "upgrade_until_score" = 25300 where "name" = 'German 480p';

-- German 720p: 8 enabled qualities merged into 'Up to 720p'
delete from "quality_group_members" where "quality_profile_name" = 'German 720p';
delete from "quality_profile_qualities" where "quality_profile_name" = 'German 720p';
delete from "quality_groups" where "quality_profile_name" = 'German 720p';
INSERT INTO quality_groups (quality_profile_name, name) VALUES ('German 720p', 'Up to 720p');
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 720p', 'Up to 720p', 'Bluray-720p', 0);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 720p', 'Up to 720p', 'WEBDL-720p', 1);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 720p', 'Up to 720p', 'WEBRip-720p', 2);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 720p', 'Up to 720p', 'HDTV-720p', 3);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 720p', 'Up to 720p', 'Bluray-480p', 4);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 720p', 'Up to 720p', 'WEBDL-480p', 5);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 720p', 'Up to 720p', 'WEBRip-480p', 6);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 720p', 'Up to 720p', 'DVD', 7);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', NULL, 'Up to 720p', 0, 1, 1);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'Raw-HD', NULL, 1, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'BR-DISK', NULL, 2, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'Remux-2160p', NULL, 3, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'Bluray-2160p', NULL, 4, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'WEBDL-2160p', NULL, 5, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'WEBRip-2160p', NULL, 6, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'HDTV-2160p', NULL, 7, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'Remux-1080p', NULL, 8, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'Bluray-1080p', NULL, 9, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'WEBDL-1080p', NULL, 10, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'WEBRip-1080p', NULL, 11, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'HDTV-1080p', NULL, 12, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'Bluray-576p', NULL, 13, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'DVD-R', NULL, 14, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'SDTV', NULL, 15, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'DVDSCR', NULL, 16, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'REGIONAL', NULL, 17, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'TELECINE', NULL, 18, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'TELESYNC', NULL, 19, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'CAM', NULL, 20, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'WORKPRINT', NULL, 21, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 720p', 'Unknown', NULL, 22, 0, 0);
update "quality_profiles" set "upgrade_until_score" = 26300 where "name" = 'German 720p';

-- German 1080p: 12 enabled qualities merged into 'Up to 1080p'
delete from "quality_group_members" where "quality_profile_name" = 'German 1080p';
delete from "quality_profile_qualities" where "quality_profile_name" = 'German 1080p';
delete from "quality_groups" where "quality_profile_name" = 'German 1080p';
INSERT INTO quality_groups (quality_profile_name, name) VALUES ('German 1080p', 'Up to 1080p');
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 1080p', 'Up to 1080p', 'Bluray-1080p', 0);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 1080p', 'Up to 1080p', 'WEBDL-1080p', 1);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 1080p', 'Up to 1080p', 'WEBRip-1080p', 2);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 1080p', 'Up to 1080p', 'HDTV-1080p', 3);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 1080p', 'Up to 1080p', 'Bluray-720p', 4);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 1080p', 'Up to 1080p', 'WEBDL-720p', 5);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 1080p', 'Up to 1080p', 'WEBRip-720p', 6);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 1080p', 'Up to 1080p', 'HDTV-720p', 7);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 1080p', 'Up to 1080p', 'Bluray-480p', 8);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 1080p', 'Up to 1080p', 'WEBDL-480p', 9);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 1080p', 'Up to 1080p', 'WEBRip-480p', 10);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 1080p', 'Up to 1080p', 'DVD', 11);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', NULL, 'Up to 1080p', 0, 1, 1);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'Raw-HD', NULL, 1, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'BR-DISK', NULL, 2, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'Remux-2160p', NULL, 3, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'Bluray-2160p', NULL, 4, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'WEBDL-2160p', NULL, 5, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'WEBRip-2160p', NULL, 6, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'HDTV-2160p', NULL, 7, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'Remux-1080p', NULL, 8, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'Bluray-576p', NULL, 9, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'DVD-R', NULL, 10, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'SDTV', NULL, 11, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'DVDSCR', NULL, 12, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'REGIONAL', NULL, 13, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'TELECINE', NULL, 14, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'TELESYNC', NULL, 15, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'CAM', NULL, 16, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'WORKPRINT', NULL, 17, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 1080p', 'Unknown', NULL, 18, 0, 0);
update "quality_profiles" set "upgrade_until_score" = 27300 where "name" = 'German 1080p';

-- German 4K: 15 enabled qualities merged into 'Up to 2160p'
delete from "quality_group_members" where "quality_profile_name" = 'German 4K';
delete from "quality_profile_qualities" where "quality_profile_name" = 'German 4K';
delete from "quality_groups" where "quality_profile_name" = 'German 4K';
INSERT INTO quality_groups (quality_profile_name, name) VALUES ('German 4K', 'Up to 2160p');
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'Bluray-2160p', 0);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'WEBDL-2160p', 1);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'WEBRip-2160p', 2);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'HDTV-2160p', 3);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'Bluray-1080p', 4);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'WEBDL-1080p', 5);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'WEBRip-1080p', 6);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'HDTV-1080p', 7);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'WEBDL-720p', 8);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'WEBRip-720p', 9);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'HDTV-720p', 10);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'Bluray-480p', 11);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'WEBDL-480p', 12);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'WEBRip-480p', 13);
INSERT INTO quality_group_members (quality_profile_name, quality_group_name, quality_name, position) VALUES ('German 4K', 'Up to 2160p', 'DVD', 14);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', NULL, 'Up to 2160p', 0, 1, 1);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'Raw-HD', NULL, 1, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'BR-DISK', NULL, 2, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'Remux-2160p', NULL, 3, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'Remux-1080p', NULL, 4, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'Bluray-720p', NULL, 5, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'Bluray-576p', NULL, 6, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'DVD-R', NULL, 7, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'SDTV', NULL, 8, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'DVDSCR', NULL, 9, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'REGIONAL', NULL, 10, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'TELECINE', NULL, 11, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'TELESYNC', NULL, 12, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'CAM', NULL, 13, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'WORKPRINT', NULL, 14, 0, 0);
INSERT INTO quality_profile_qualities (quality_profile_name, quality_name, quality_group_name, position, enabled, upgrade_until) VALUES ('German 4K', 'Unknown', NULL, 15, 0, 0);
update "quality_profiles" set "upgrade_until_score" = 28300 where "name" = 'German 4K';

-- --- Delay profile: German releases (score >= 15000) skip the delay,
-- everything else waits so a German release has time to show up.

update "delay_profiles" set "bypass_if_above_custom_format_score" = 1, "minimum_custom_format_score" = 15000 where "name" = 'Default';
