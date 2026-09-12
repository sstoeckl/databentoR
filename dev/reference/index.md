# Package index

## Authentication

- [`db_has_key()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_has_key.md)
  : Is a Databento API key configured?

## Metadata

Discovery and previews. Every endpoint here is free of charge, which is
why a cost preview belongs in front of every download.

- [`db_list_publishers()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_publishers.md)
  : List the publishers Databento serves
- [`db_list_datasets()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_datasets.md)
  : List available datasets
- [`db_list_schemas()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_schemas.md)
  : List the schemas available for a dataset
- [`db_list_fields()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_fields.md)
  : List the fields of one schema and encoding
- [`db_list_unit_prices()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_unit_prices.md)
  : List the unit prices of a dataset
- [`db_get_dataset_condition()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_dataset_condition.md)
  : Report the condition of a dataset, day by day
- [`db_get_dataset_range()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_dataset_range.md)
  : Report the available date range of a dataset
- [`db_get_record_count()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_record_count.md)
  : Count the records a request would return
- [`db_get_billable_size()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_billable_size.md)
  : Report the billable size of a request in bytes
- [`db_get_cost()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_cost.md)
  : Preview the cost of a request in US dollars

## Time series

The one billed endpoint, and the column types it assigns.

- [`db_get_range()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_range.md)
  : Download a historical range as a tibble
- [`db_field_types()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_field_types.md)
  : Column types databentoR gives a CSV download

## Symbology

- [`db_resolve()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_resolve.md)
  : Resolve symbols from one symbol type to another

## Batch jobs

Asynchronous delivery for requests too large to stream.

- [`db_batch_submit_job()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_submit_job.md)
  : Submit a batch job
- [`db_batch_get_job_details()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_get_job_details.md)
  : Look up one batch job
- [`db_batch_list_jobs()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_list_jobs.md)
  : List your batch jobs
- [`db_batch_list_files()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_list_files.md)
  : List the files a finished batch job produced
- [`db_batch_download()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_download.md)
  : Download the output of a batch job

## Reference data

Corporate actions, adjustment factors and the security master.

- [`db_adjustment_factors()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_adjustment_factors.md)
  : Corporate-action adjustment factors
- [`db_corporate_actions()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_corporate_actions.md)
  : Corporate actions
- [`db_corporate_action_events()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_corporate_action_events.md)
  : List the corporate-action event types
- [`db_corporate_action_enums()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_corporate_action_enums.md)
  : List the corporate-action enumerations
- [`db_security_master()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_security_master.md)
  : Security master over a time range
- [`db_security_master_last()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_security_master_last.md)
  : Latest security-master record per security

## Value domains

- [`db_schemas()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md)
  [`db_stypes()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md)
  [`db_encodings()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md)
  [`db_compressions()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md)
  : Schemas, symbol types, encodings and compressions
