# List the files a finished batch job produced

Mirrors `batch.list_files`.

## Usage

``` r
db_batch_list_files(job_id)
```

## Arguments

- job_id:

  Job identifier, as returned by
  [`db_batch_submit_job()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_submit_job.md).

## Value

A tibble with `filename`, `hash`, `size` and the download `url`.

## See also

Other batch:
[`db_batch_download()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_download.md),
[`db_batch_get_job_details()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_get_job_details.md),
[`db_batch_list_jobs()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_list_jobs.md),
[`db_batch_submit_job()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_submit_job.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_batch_list_files("GLBX-20240101-ABCDEF")
} # }
```
