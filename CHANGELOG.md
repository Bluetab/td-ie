# Changelog

## [Unreleased]

### Added

- [TD-1560] Enriched description field in template content

### Changed

- [TD-1985] Type of template field user with an aggregation size of 50
- [TD-1995] add new file description in ingest_executions
- [TD-2037] Bump cache version due to lack of performance

## [3.2.0] 2019-07-24

### Removed

- [TD-1994] Remove deprecated relations (parent_id, related_to) from model

### Changed

- [TD-2002] Update td-cache and delete permissions list from config

## [3.1.0] 2019-07-08

### Changed

- [TD-1618] Cache improvements (use td-cache instead of td-perms)
- [TD-1924] Use Jason instead of Poison for JSON encoding/decoding

## [3.0.0] 2019-06-25

### Changed

- [TD-1893] Use CI_JOB_ID instead of CI_PIPELINE_ID

## [2.21.0] 2019-06-04

### Changed

- [TD-1789] update ES mappings according to template format

## [2.20.0] 2019-05-27

### Fixed

- [TD-1774] Newline is missing in logger format

### Changed

- Updated dependencies: phoenix 1.4, ecto 3.0, td_df_lib 2.19.3, td_perms 2.19.1

## [2.16.0] 2019-04-02

### Added

- [TD-1571] Elixir's Logger config will check for EX_LOGGER_FORMAT variable to override format
- [TD-1573] On IngestExecutions adds file_name and file_size and makes end_timestamp not required

## [2.12.2] 2019-01-29

### Fix

- [TD-1371] Fix end-point to add executions by name when there are many versions

## [2.12.1] 2019-01-28

### Fix

- [TD-1371] Fix end-point to add executions by name

## [2.12.0] 2019-01-15

### Added

- [TD-1371] Added end-point to add executions by name

## [2.11.0] 2019-01-15

### Added

- Added support for Ingest Executions

## [0.0.3] 2018-12-07

### Added

- New post endpoint which recieves some params in order to narrow the retrieved filters

## [0.0.2] 2018-12-03

### Added

- Adding new permissions to td_perms library

## [0.0.1] 2018-11-30

### Added

- Release version
