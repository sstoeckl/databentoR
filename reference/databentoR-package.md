# databentoR: R Client for the 'Databento' Historical and Reference Data API

A complete R client for the 'Databento' market data HTTP API
<https://databento.com>: dataset and schema discovery, free cost and
record-count previews, streaming range downloads, symbology resolution,
asynchronous batch jobs, and the reference data endpoints for corporate
actions, adjustment factors and the security master. Argument names,
defaults and wire format mirror the official 'Python' client, and the
package ships an equivalence test suite that compares both clients
request by request. Results are returned as tibbles or written to
'parquet'. Neither 'Python' nor the binary 'DBN' format is required,
because the client uses the comma-separated encoding of the HTTP API.

## See also

Useful links:

- <https://github.com/sstoeckl/databentoR>

- <https://www.sebastianstoeckl.com/databentoR/>

- Report bugs at <https://github.com/sstoeckl/databentoR/issues>

## Author

**Maintainer**: Sebastian Stöckl <sebastian.stoeckl@uni.li>
([ORCID](https://orcid.org/0000-0002-4196-6093))

Authors:

- Sebastian Stöckl <sebastian.stoeckl@uni.li>
  ([ORCID](https://orcid.org/0000-0002-4196-6093))
