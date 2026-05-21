-- @operation: export
-- @entity: batch
-- @name: add illegal character rename
-- @exportedAt: 2026-05-21T07:55:28.073Z
-- @opIds: 404, 405

-- --- BEGIN op 404 ( update sonarr_naming "default" )
update "sonarr_naming" set "replace_illegal_characters" = 1 where "name" = 'default' and "replace_illegal_characters" = 0;
-- --- END op 404

-- --- BEGIN op 405 ( update radarr_naming "default" )
update "radarr_naming" set "replace_illegal_characters" = 1 where "name" = 'default' and "replace_illegal_characters" = 0;
-- --- END op 405
