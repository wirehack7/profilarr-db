-- @operation: export
-- @entity: batch
-- @name: remove any profile
-- @exportedAt: 2026-05-21T07:56:48.889Z
-- @opIds: 407

-- --- BEGIN op 407 ( delete quality_profile "Any" )
delete from "quality_profile_tags" where "quality_profile_name" = 'Any';

delete from "quality_profile_languages" where "quality_profile_name" = 'Any';

delete from "quality_profile_qualities" where "quality_profile_name" = 'Any';

delete from "quality_profile_custom_formats" where "quality_profile_name" = 'Any';

delete from "quality_groups" where "quality_profile_name" = 'Any';

delete from "quality_profiles" where "name" = 'Any';
-- --- END op 407
