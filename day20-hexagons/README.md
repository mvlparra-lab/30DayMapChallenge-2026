# Day 20 | Tokyo Through Photographs

#30DayMapChallenge 2026 · Hexagons · María Victoria León Parra

Where do the photographs in the tutorial’s Tokyo sample concentrate, and what groups does DBSCAN identify?

## Tools

Python 3.11+, GeoPandas, scikit-learn, SciPy, Matplotlib and Jupyter. The print layout uses the bundled Roboto fonts.

## Workflow

1. Reproject WGS 84 coordinates to Japan Plane Rectangular CS IX (EPSG:6677) for local distances in metres. The rectangular frame encloses every retained record and extends beyond Tokyo’s administrative boundary. [CRS definition](https://epsg.io/6677)
2. Explore the point scatter, mean center, Euclidean median and standard distance (7.13 km). Inspect sorted distances to the 100th sample, counting each query photograph itself, as a neighbourhood-scale diagnostic.
3. Run DBSCAN with Euclidean distances. Epsilon defines the neighbourhood radius. Minimum samples sets the number of photographs, including the point itself, required to be a core point. Connected cores can produce a cluster wider than epsilon. Other points reached by a core are border members. Noise is labelled −1. Cluster IDs are arbitrary and can start at zero.
4. Select 500 m and 100 samples, adapting the chapter’s example to local ground metres. A 350 m radius with the same threshold split the pattern into 16 smaller groups and left 5,564 noise records. At 500 m and 50 samples the largest group grew to 3,506. At 650 m and 100 samples it grew to 5,189. The selected setting retains separate central concentrations at a neighbourhood scale and uses the chapter’s approximate 1% core threshold.
5. Count photographs in flat-top hexagons with 375 m sides, 750 m across opposite vertices, about 650 m across flats and 0.365 km² per cell. This resolution distinguishes the Asakusa, Ueno and Shibuya peaks. The lattice is anchored to the CRS origin. Shared-edge ties go to the first cell in fixed lattice order. The GeoPackage stores complete hexagons and the map clips edge cells to the frame. Positive counts use a logarithmic ramp. An unfilled cell records zero sample photographs. Areas outside the grid have no assigned count.
6. For each of the four largest clusters, draw the outline of the dissolved hexagons where more than half of all photographs, including noise in the denominator, belong to that cluster. These outlines describe majority membership at the grid resolution. The GeoPackage also keeps the dissolved 125 m buffers for all 12 clusters as a separate analytical layer.
7. Compose the dark print map with a centered title and footer anchor, a 5 km scale bar in the lower right and Tokyo Bay as the sole place label. The magenta cluster outlines follow the hexagon edges. Source credits are recorded in the project documentation.

## Local data and reproduction

Install the requirements from this day’s directory. The CSV, Natural Earth crop and Roboto fonts are bundled for offline runs. The workflow retrieves the source CSV if the local copy is absent.

```sh
python -m pip install -r requirements.txt
python make_map.py
jupyter nbconvert --to notebook --execute --inplace day20_hexagons.ipynb
```

The last command is the notebook equivalent of running the script. You can also open the notebook in a Jupyter frontend and run all cells.

## Sources and inspiration

- Flickr contributors and Yahoo Flickr Creative Commons 100 Million (YFCC100M), published by Thomee et al. The original corpus describes Flickr uploads from 2004 to early 2014. [Original dataset paper](https://arxiv.org/abs/1503.01817)
- Serge J. Rey, Dani Arribas-Bel and Levi J. Wolf use this sample in *Geographic Data Science with Python*. Their preparation page documents shuffling a Tokyo table with seed 1234 and retaining 10,000 records. This project bundles the book repository’s CSV snapshot and verifies it by SHA-256. The documentation does not establish the extraction history of individual records, their upload timestamps or a formal sampling boundary. [Point Pattern Analysis](https://geographicdata.science/book/notebooks/08_point_pattern_analysis.html) · [Sample preparation](https://geographicdata.science/book/data/tokyo/tokyo_cleaning.html) · [Book CSV](https://raw.githubusercontent.com/gdsbook/book/master/data/tokyo/tokyo_clean.csv)
- The bundled context uses Natural Earth 1:10m land cropped to 139.45–140.04°E and 35.45–35.88°N before projection. The generalized coastline is for orientation. The GO TOKYO visitor map supports the place associations in the findings. [Natural Earth land](https://www.naturalearthdata.com/downloads/10m-physical-vectors/10m-land/) · [Land archive](https://naturalearth.s3.amazonaws.com/10m_physical/ne_10m_land.zip) · [GO TOKYO map](https://www.gotokyo.org/book/wp-content/uploads/2025/11/2511_mapoftokyo_EN_2_low.pdf)

The seven fields are `user_id`, `longitude`, `latitude`, `date_taken`, `photo/video_page_url`, `x` and `y`. Longitude and latitude are in WGS 84 (EPSG:4326) and the supplied `x`/`y` pair matches Web Mercator (EPSG:3857). The file has no null fields, invalid coordinates, identical rows or repeated photo URLs. It has 1,825 distinct user IDs. All 2,713 rows that repeat a previously seen coordinate pair are retained.

Reported capture timestamps span 1923-09-01 to 2017-05-14. Of these, 9,915 fall in 2004–2014 inclusive and 85 fall outside those years, including three in 2017. The capture values and the corpus’s reported upload period are different fields. The reason for the discrepancy, the timestamps’ time zone and their accuracy are unknown. The analysis retains those records and uses coordinates alone.

## Findings

The 10,000 photographs occupy 977 of 4,104 hexagons. The busiest cell is near Asakusa (266), followed by cells near Ueno Park (214) and Shibuya Station (190). Central Tokyo contains the strongest broad concentration, with pockets toward the waterfront and west of the city center.

DBSCAN groups 5,975 photographs into 12 clusters and assigns 4,025 to noise. The four largest groups are around Ginza and the Tokyo Station area (1,604), Shibuya–Harajuku (924), Ueno and its surroundings (888), and Shinjuku (629). The smaller Asakusa group contains 399 photographs. Place names describe approximate locations.

## Notes and limitations

Counts describe sampled Flickr photographs. They cannot estimate tourists, visits or population. Participation on Flickr, geotagging, Creative Commons selection, prolific contributors, positional accuracy and the subset’s selection can all affect the pattern. The spatial window and grid size and origin affect its appearance. DBSCAN describes groups under the chosen settings and establishes neither statistical significance nor causes.

## Outputs

- `outputs/day20-tokyo-through-photographs.png` and `.pdf` share a 300 × 300 mm layout with a 5 mm footer clearance and at least 10 mm margins for the other content. The PNG is 300 dpi. The PDF uses vector geometry and embedded fonts.
- `outputs/tokyo_photographs.gpkg` stores the `photographs` (source row, cell ID, cluster label and role), `hexagon_counts`, `dbscan_footprints`, `dbscan_hexagon_outlines` and `land_context` layers in EPSG:6677.
- `outputs/input_audit.json`, `point_pattern_summary.csv`, `dbscan_sensitivity.csv`, `dbscan_clusters.csv` and `hexagon_counts.csv` record data quality, the descriptive spatial measures, parameter comparison, cluster sizes and cell counts.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/portfolio) · [Back to challenge](../)
