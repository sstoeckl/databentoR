# List your batch jobs

Mirrors `batch.list_jobs`.

## Usage

``` r
db_batch_list_jobs(
  states = c("queued", "processing", "done"),
  since = NULL,
  short = NULL
)
```

## Arguments

- states:

  Job states to include, as a character vector or a single
  comma-separated string: `"queued"`, `"processing"`, `"done"`,
  `"expired"`.

- since:

  Optional lower bound on the job's received timestamp.

- short:

  Ask the server for only `id`, `state` and `ts_received`, which is the
  cheap way to poll.

## Value

A tibble with one row per job.

## See also

Other batch:
[`db_batch_download()`](https://www.sebastianstoeckl.com/databentoR/reference/db_batch_download.md),
[`db_batch_get_job_details()`](https://www.sebastianstoeckl.com/databentoR/reference/db_batch_get_job_details.md),
[`db_batch_list_files()`](https://www.sebastianstoeckl.com/databentoR/reference/db_batch_list_files.md),
[`db_batch_submit_job()`](https://www.sebastianstoeckl.com/databentoR/reference/db_batch_submit_job.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_batch_list_jobs(states = "done")
} # }
```
