smires
================

SMIRES is a COST Action addressing the Science and Management of Intermittent Rivers & Ephemeral Streams. SMIRES brings together more than 200 hydrologists, biogeochemists, ecologists, modellers, environmental economists, social researchers and stakeholders from 31 different countries to develop a research network for synthesising the fragmented, recent knowledge on IRES, improving our understanding of IRES and translating this into a science-based, sustainable management of river networks. More information about SMIRES can be found at <http://www.smires.eu/>.

This git repository hosts the R-package `smires`, one of several outcomes of Working Group 1 (WG1, Prevalence, distribution and trends of IRES). Given time series of daily (weekly, monthly) discharges, its purpose is:

-   to estimate if it was observed at an intermittent river,
-   to calculate relevant low flow and drought metrics.

Installation of the R-package
=============================

In order to use the development version of the package `smires` you will need to have to install the package `devtools`.

``` r
install.packages("devtools")
install_github("mundl/smires")
```

Examples
========

Each participating country was asked to suggest metrics and to submit a few time series with intermittent streamflow.

| country | time series | metrics |
|:--------|:------------|:--------|
| lt      | TRUE        | NA      |
| es      | TRUE        | NA      |
| pl      | TRUE        | NA      |
| it      | TRUE        | NA      |
| fr      | TRUE        | NA      |
| gb      | TRUE        | NA      |
