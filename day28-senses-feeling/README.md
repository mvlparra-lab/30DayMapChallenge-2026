# Day 28 | Cádiz, Feeling the Heat

#30DayMapChallenge 2026 · Senses: Feeling · María Victoria León Parra

Annual mean air temperature anomalies from Cádiz Observatorio run from top to bottom across the city silhouette. Each horizontal stripe represents one calendar year. The station series describes change over time across the full silhouette. It provides no neighbourhood-level measurements.

## Tools

R, climaemet, sf, ggplot2, ggspatial, RColorBrewer, ragg, sysfonts and showtext.

## Workflow

1. Retrieve and cache the official temperature records for Cádiz Observatorio, station 5973.
2. Check calendar coverage and calculate the annual temperature series and reference anomalies.
3. Prepare the Cádiz peninsula outline and intersect it with one stripe per year. Use the full land geometry for the soft shadow, rasterized with ragg and blurred with R's built-in stats package.
4. Export the halo map as a print PNG and PDF, and write the annual temperature and coverage table.

- **Calendar coverage.** A valid year needs a finite official `tm_mes` value for every month from January through December, with only one distinct record per month after `climaemet` removes identical records. When that condition holds, the script uses the official annual value (month 13) if present and unambiguous. Otherwise it weights the 12 official monthly means by calendar days, including leap days. Years with missing or conflicting monthly summaries stay grey. This checks coverage of published monthly means. Daily coverage within those summaries is outside this check.
- **Reference.** A 30-year reference needs at least 24 complete years and no gap longer than three consecutive years. The script checks 1991–2020 first, then 1981–2010 and 1961–1990, then rolling 30-year windows from latest to earliest. The baseline is the arithmetic mean of the complete annual values in the selected window. If no window qualifies, the script writes the coverage CSV and stops before export.

## Local data and reproduction

The Cádiz boundary and fonts are bundled in `data/`.

Install the R packages from CRAN.

```r
install.packages(c("climaemet", "sf", "ggplot2", "ggspatial",
                   "RColorBrewer", "ragg", "sysfonts", "showtext"))
```

Get a free [AEMET OpenData API key](https://opendata.aemet.es/centrodedescargas/altaUsuario). Set it in the environment as `AEMET_API_KEY` or create a local `.Renviron` in this day’s folder containing `AEMET_API_KEY=your_actual_key`. Git ignores that file. The script reads it directly when needed, including under `--vanilla`.

From `day28-senses-feeling/`, run:

```sh
Rscript --vanilla day28-senses-feeling.R
```

The first run requires internet access for AEMET. Validated responses are cached by year under `data/cache/aemet-monthly/`, so later runs use local data for those years and retry any failed requests. With a complete cache, the script runs offline without a key. To refresh a year, remove its RDS entry and rerun with the key available. Adjust the year window, reference settings, southern cut and page parameters at the top of the script.

## Sources and inspiration

- **Temperature.** AEMET confirms that station 5973 is Cádiz, Observatorio. Its public extremes inventory lists temperature coverage beginning in 1955. This establishes the earliest year to query. The workflow checks official monthly and annual records for 1955–2025 through `climaemet`. The actual usable span and exclusions depend on the retrieved records. [AEMET station identity](https://www.aemet.es/documentos/es/noticias/2023/Efemeridesdiciembre2022.pdf) · [AEMET temperature coverage](https://www.aemet.es/en/serviciosclimaticos/datosclimatologicos/efemerides_extremos%2A?datos=det&k=and&l=5973&m=13&v=todos&w=0&x=5973) · [climaemet](https://ropenspain.github.io/climaemet/reference/aemet_monthly.html)
- **Boundary.** The bundled GeoJSON is IGN-CNIG’s BDLJE feature for Cádiz municipality, ID `34011111012` (INE 11012), retrieved from its INSPIRE Administrative Units WFS. The script validates and projects it to ETRS89 / UTM 29N (EPSG:25829), clips at northing 4,041,700 m near Cortadura to omit the southern municipal land and saltmarsh, and keeps the largest connected piece. Intersecting bands with this outline preserves its proportions. The resulting silhouette depicts the city peninsula, including its port, and omits detached islets. Derived from BDLJE, CC BY 4.0. [IGN-CNIG dataset and licence](https://centrodedescargas.cnig.es/CentroDescargas/limites-municipales-provinciales-autonomicos) · [WFS documentation](https://www.ign.es/resources/noticias/Noticia_WFS_UA_IGN.pdf)
- **Design.** The map adapts Dominic Royé’s reversed RdBu palette and one-band-per-year layout, based on Ed Hawkins’ warming stripes. The colour scale is symmetric about zero, with blues below the reference and reds above it. The 300 × 300 mm page has 10 mm margins and uses bundled Roboto. [Royé’s tutorial](https://dominicroye.github.io/blog/how-to-create-warming-stripes-in-r/index.html) · [Ed Hawkins’ Show Your Stripes](https://showyourstripes.info/) · [Roboto licence](data/Roboto-LICENSE.txt)

## Notes and limitations

The current halo edition uses a radial gradient from `#327B90` behind the silhouette to `#1B4C5D` at the page edges. The decorative coastal waves follow successive 105 m exterior buffers. For the waves only, the script fills interior holes and closes narrow harbour entrances. Opacity peaks at 21% and fades with distance from the coastline and smoothly to zero near the edges of the wave field, leaving the title and footer clear. The scale bar refers to the projected upper face. A 0.5 mm down-right edge, pale rim and soft shadow give the silhouette a gently raised appearance. The shadow uses the complete land geometry at 30% opacity, with a 0.3 mm offset and an approximately 1 mm Gaussian blur. These effects are decorative. The 300 dpi face has shared stripe edges, and the year leaders use the centres of the clipped stripe geometries. The 2025 label reports the observed anomaly of **+1.84 °C**.

The 95th percentile of absolute anomalies is **1.68 °C**, rounded outward to a symmetric colour range of **−1.7 to +1.7 °C** about zero. The three anomalies above the upper limit occur in **2022, 2023 and 2025** (each **+1.84 °C**). They share the top colour, labelled **≥ +1.7**, while their calculated anomalies remain in the CSV. The halo edition labels the lower colour endpoint **≤ −1.7** for symmetry. No observed anomaly reaches that lower limit. Missing and excluded years use the same muted grey-blue as the legend key.

The map shows 1955–2025. The **57 complete years** span 1956–2025 and all use AEMET’s annual summaries. Grey marks the 14 years with missing monthly means: **1955, 1979–1981, 1986–1987, 1989, 1997, 1999–2000, and 2009–2012**.

The preferred 1991–2020 window has 23 complete years. The 1981–2010 window has 21. The selected **1961–1990** reference uses **24 complete years** with a mean of **18.16 °C**. Plotted anomalies range from **−1.26 to +1.84 °C**.

The series uses one station and applies no homogenization for station moves or instrument changes.

## Outputs

- The [annual temperature CSV](data/cadiz-5973-annual-temperature.csv) records each year’s annual mean, valid month count, excluded months, aggregation method, reference and anomaly.
- The [refined halo PNG](outputs/day28-cadiz-feeling-the-heat-halo-waves.png) and [refined halo PDF](outputs/day28-cadiz-feeling-the-heat-halo-waves.pdf) are the current script outputs. The PNG is 3543 × 3543 pixels at 300 dpi.
- The [first halo PNG](outputs/day28-cadiz-feeling-the-heat-halo.png) preserves the previous halo layout.
- The [previous PNG](outputs/day28-cadiz-feeling-the-heat.png) and [previous PDF](outputs/day28-cadiz-feeling-the-heat.pdf) preserve the earlier layout.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/portfolio) · [Back to challenge](../)
