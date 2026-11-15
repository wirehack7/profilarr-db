-- @operation: export
-- @entity: batch
-- @name: penalize double-title releases
-- @exportedAt: 2026-11-15T00:00:00.000Z

-- Unwanted: Double Title  -14000
--
--   Some German groups name releases "<English Title> - <German Title>", e.g.
--   "Adventure.Time.-.Abenteuerzeit.mit.Finn.und.Jake.S05E04.German.DL...-MRW".
--   Sonarr parses the whole "Adventure Time - Abenteuerzeit mit Finn und Jake"
--   as the series title, which matches no known title or alias. The grab works
--   via the search ID, but the import fails with "release was matched to series
--   by ID. Automatic import is not possible." and needs a manual import.
--
--   The regex matches a standalone " - " / ".-." / "_-_" between two title
--   parts before SxxEyy or a season pack Sxx. Hyphens inside words (X-Men,
--   Spider-Man), the "-GROUP" suffix, episode titles after SxxEyy, dates and
--   anime "Title - 05" do not match.
--
--   Score: -14000 puts a double-title release below every parseable release of
--   the same language tier and keeps it under the 15000 delay bypass:
--     German DL (25000)      parseable   25000 .. 28800
--     German Only (15000)    parseable   15000 .. 18800
--     German DL              double      11000 .. 14800
--     German Only            double       1000 ..  4800
--     English                parseable       0 ..  3800
--   German is still grabbed when nothing else exists, and a parseable German
--   release replaces it later. Series whose official title contains " - " are
--   affected as well. Movies never match (no SxxEyy).

-- --- Cleanup (idempotency)

delete from "quality_profile_custom_formats" where "custom_format_name" = 'Unwanted: Double Title';
delete from "condition_patterns" where "custom_format_name" = 'Unwanted: Double Title';
delete from "custom_format_conditions" where "custom_format_name" = 'Unwanted: Double Title';
delete from "custom_format_tags" where "custom_format_name" = 'Unwanted: Double Title';
delete from "custom_formats" where "name" = 'Unwanted: Double Title';
delete from "regular_expressions" where "name" = 'Unwanted: Double Title :: Title - Title';

-- --- Regular expression

INSERT INTO regular_expressions (name, pattern) VALUES ('Unwanted: Double Title :: Title - Title', '(?i)^(?:[^.\s_]+[. _])+?-[. _](?:[^.\s_]+[. _])+?S\d{1,4}(?:E\d{1,4}|\b)');

-- --- Custom format

INSERT INTO custom_formats (name, description, include_in_rename) VALUES ('Unwanted: Double Title', 'Penalizes "English Title - German Title" releases that Sonarr cannot import automatically', 0);

INSERT INTO custom_format_conditions (custom_format_name, name, type, arr_type, negate, required) VALUES ('Unwanted: Double Title', 'Title - Title', 'release_title', 'all', 0, 1);

INSERT INTO condition_patterns (custom_format_name, condition_name, regular_expression_name) VALUES ('Unwanted: Double Title', 'Title - Title', 'Unwanted: Double Title :: Title - Title');

-- --- Scores

INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 480p', 'Unwanted: Double Title', 'all', -14000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 720p', 'Unwanted: Double Title', 'all', -14000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 1080p', 'Unwanted: Double Title', 'all', -14000);
INSERT INTO quality_profile_custom_formats (quality_profile_name, custom_format_name, arr_type, score) VALUES ('German 4K', 'Unwanted: Double Title', 'all', -14000);
