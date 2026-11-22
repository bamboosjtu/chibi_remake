extends RefCounted
## One supported wire format. Earlier versions are rejected, never migrated.
const VERSION := 9
const WORLD_FIELDS := ["rngState","contentRevision","rulesRevision","tick","accumulator","speedIndex","explored","projectiles","fireFields","decorResources","aiResources","groups","taskLatches","officerProgress","terrainChanges","taskEvents","objectiveDone","officerPool","playerTech","armyTech","researchJobs","ai","autoControl"]
