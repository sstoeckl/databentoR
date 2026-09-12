# Download the output of a batch job

Mirrors `batch.download`. With `filename_to_download = NULL` the whole
job is fetched as one zip archive and unpacked; naming a single file
fetches just that file from the job manifest.

## Usage

``` r
db_batch_download(
  job_id,
  output_dir = ".",
  filename_to_download = NULL,
  keep_zip = FALSE
)
```

## Arguments

- job_id:

  Job identifier, as returned by
  [`db_batch_submit_job()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_submit_job.md).

- output_dir:

  Directory to write into; a subdirectory named after the job is created
  inside it. Defaults to the working directory.

- filename_to_download:

  Optional single file from the job manifest.

- keep_zip:

  Keep the archive after unpacking it. Only meaningful when downloading
  a whole job.

## Value

A character vector of the paths written, invisibly.

## Details

A file that already exists locally at the size the manifest reports is
left alone, so an interrupted download resumes by calling the function
again. When the `digest` package is installed, each file's SHA-256 is
checked against the manifest and a mismatch raises a warning.

## See also

Other batch:
[`db_batch_get_job_details()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_get_job_details.md),
[`db_batch_list_files()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_list_files.md),
[`db_batch_list_jobs()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_list_jobs.md),
[`db_batch_submit_job()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_submit_job.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_batch_download("GLBX-20240101-ABCDEF", output_dir = tempdir())
} # }
```
