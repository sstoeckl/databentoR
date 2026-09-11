# Äquivalenz-Protokoll: databentoR vs. offizieller Python-Client

**Zweck (Sebastians Vorgabe 11.09.2026):** regelmäßig prüfen, dass die
R-Implementierung exakt dieselben Daten liefert wie der offizielle
Python-Client.

## Protokoll

1. **Referenz einfrieren (einmalig / bei Bedarf):** `make_reference.py`
   (QA-Werkzeug — der EINZIGE geduldete Python-Code im Projekt) lädt fest
   definierte Mini-Slices über den offiziellen Client und schreibt sie als
   Parquet nach `reference/` (untracked — Databento-Daten dürfen NICHT
   redistribuiert werden, deshalb nie committen!).
2. **Vergleichen:** `tests/testthat/test-equivalence.R` lädt dieselben
   Slices über databentoR und vergleicht 1:1 (Zeilenzahl, OHLCV-Werte auf
   1e-12, Symbole). Läuft automatisch bei jedem `devtools::test()`, wird
   ohne Key/Fixtures sauber geskippt.
3. **Regelmäßig:** `.github/workflows/equivalence.yaml` (wöchentlicher
   Cron, sobald das Repo auf GitHub liegt; braucht Repo-Secret
   `DATABENTO_API_KEY`) baut die Python-Referenz frisch UND lässt die
   R-Tests laufen — Drift zwischen beiden Clients oder API-Änderungen
   fallen sofort auf.

## Referenz-Slices (bewusst winzig, Kosten je « 0,01 USD; Metadaten gratis)

| Fixture | Request |
|---|---|
| `glbx_es_ohlcv1d_2024-01.parquet` | GLBX.MDP3, ohlcv-1d, ES.FUT, 2024-01-01→2024-02-01 |
| `glbx_zq_ohlcv1d_2024-01.parquet` | GLBX.MDP3, ohlcv-1d, ZQ.FUT, 2024-01-01→2024-02-01 |
| `opra_djt_ohlcv1d_2024-10-w1.parquet` | OPRA.PILLAR, ohlcv-1d, DJT.OPT, 2024-10-01→2024-10-08 |

Neue Slices: Tabelle hier ergänzen + in `make_reference.py` UND
`test-equivalence.R` nachziehen (immer paarweise!).

## Hinweis „gratis Testdaten"

Es gibt keine dedizierten Gratis-Testdatensätze über die API, aber:
(a) **alle metadata.*-Endpunkte sind kostenlos** (Datasets, Schemas,
Kosten-Previews), (b) Mini-Slices wie oben kosten Bruchteile eines Cents
und laufen praktisch kostenlos übers Startguthaben. Das ist die Basis
der goldenen Tests.
