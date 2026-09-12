# Look up one batch job

Mirrors `batch.get_job_details`.

## Usage

``` r
db_batch_get_job_details(job_id)
```

## Arguments

- job_id:

  Job identifier, as returned by
  [`db_batch_submit_job()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_submit_job.md).

## Value

A one-row tibble of the job's properties.

## See also

Other batch:
[`db_batch_download()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_download.md),
[`db_batch_list_files()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_list_files.md),
[`db_batch_list_jobs()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_list_jobs.md),
[`db_batch_submit_job()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_submit_job.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_batch_get_job_details("GLBX-20240101-ABCDEF")
} # }
```
