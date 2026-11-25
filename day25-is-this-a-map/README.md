# Day 25 | Bruges, Drawn to Water

#30DayMapChallenge 2026 · Is this a map? · María Victoria León Parra

Fine blue strokes trace the relationship between buildings and water in Bruges, Belgium. Each stroke begins at a building centroid and ends at the closest point on an eligible waterway. Their overlap gives the historic centre and surrounding neighbourhoods a feather-like texture.

## Tools

Python 3.12, GeoPandas, Shapely, NumPy, Matplotlib, pyproj, Pyogrio, Requests and OSMnx for reading OSM XML. See `requirements.txt` for versions. The 240 × 340 mm portrait layout uses the bundled Roboto Regular and Bold fonts and places the title below the artwork.

## Workflow

1. Query OpenStreetMap API 0.6 for a grid of 0.02° × 0.02° tiles covering the 5.6 × 7.4 km portrait study frame plus a minimum 3.4 km waterway search buffer. Subdivide tiles that exceed the API's node limit. Merge tile elements by OSM type and ID before assembling features so multipolygon members can be shared across tiles.
2. Project the geometry to WGS 84 / UTM zone 31N (EPSG:32631). Repair footprints, retain positive-area polygon parts, and collapse geometrically identical footprints. Keep one centroid per resulting footprint when the centroid falls inside the study frame.
3. Index the full eligible waterway geometries with Shapely's STRtree. Query for exact point-to-line distances. Use the first sorted OSM identifier to resolve ties and save the shortest segment and its length in projected metres.
4. Offset the quadratic Bézier control point perpendicular to the straight segment by 28% of the segment length, consistently on the same side looking from the building to water. The visual curve keeps both original endpoints and is stored as a 33-vertex LineString. The curves and waterways are clipped only by the print frame during rendering.
5. Verify all analytical lengths and endpoints and compare 256 indexed matches with brute-force geometry distances. For each centroid, confirm that the match is closer than the edge of the downloaded coverage.

## Local data and reproduction

From this day's directory in a Python 3.12 virtual environment, run

```sh
python -m pip install -r requirements.txt
python make_map.py --preview
python make_map.py
```

The first command after installation writes a low-resolution proof. The final run writes the print files, GeoPackage and validation report. The script reuses compressed OSM XML tiles in `data/osm/`, so reruns with the default frame are offline. Missing tiles are downloaded automatically. `data/sources.json` records each request URL and its UTC retrieval timestamp.

Set `CENTRE`, `WIDTH_M`, `BUFFER_M` and `WATER_TYPES` near the top of `make_map.py` to change the study area or matching rules. Line widths, opacity, palette and the distance scale for fading longer strokes are grouped there as well. Use `--curvature 0.28` to set the signed control offset as a fraction of the straight distance. A value of zero produces straight strokes.

## Sources and inspiration

- **Geometries.** OpenStreetMap buildings and waterway centrelines, downloaded on 19 November 2026 via the OSM API 0.6 bounding-box endpoint. © OpenStreetMap contributors, ODbL. [Map API](https://wiki.openstreetmap.org/wiki/API_v0.6#Retrieving_map_data_by_bounding_box:_GET_/api/0.6/map) · [Copyright and licence](https://www.openstreetmap.org/copyright)
- **Hydrolinks / HydroThreads.** Lika Zhvania's original PyQGIS script creates straight two-point connections from Augsburg building centroids to water. Its QGIS Geometry Generator style then constructs a three-point line through the centroid of an offset curve. The Bruges adaptation uses exact indexed geometry distances and its own deterministic quadratic Bézier rendering. [Project](https://github.com/likazhvania/hydrolinks) · [Original PyQGIS script](https://github.com/likazhvania/hydrolinks/blob/main/scripts/connect_points_to_river.py) · [Original rendering expression](https://github.com/likazhvania/hydrolinks/blob/main/style/curve_lines.txt)

## Findings

The 76 cached tiles yielded 58,282 building centroids in the study frame and 100 eligible waterway features in the search area, including 95 canal features and five river features. The median connection measures 407 m and the longest measures 2,975 m. For 728 buildings, the nearest eligible point lies beyond the print frame.

The extract also contains 1,087 stream features, 293 drains and 1,066 ditches. One of these classes offers a closer match for 38,078 buildings. The map therefore describes proximity to the river and canal network specifically. The print uses a fine stroke and fades longer connections to retain more of the individual linework. It also reduces opacity for buildings close to the frame edge to soften the crop.

## Notes and limitations

- The default analysis includes OSM `river` and `canal` centrelines, including mapped covered segments tagged with those classes. Streams belong to a smaller channel class, while drains and ditches generally represent local drainage. These classes are counted in the review and excluded from the default definition. Classification depends on OSM tagging. [OSM waterway tags](https://wiki.openstreetmap.org/wiki/Key:waterway)
- Distances measure straight-line geometric proximity to mapped centrelines. Walking routes, drainage connections, bank locations, barriers and measured accessibility are outside the model. Use `distance_m` for analysis. The decorative curve length depends on the chosen bend.
- Centroids of concave or multipart buildings can fall outside their footprints. The buffer check guards against missing closer waterways outside the downloaded extent. The OSM API selects ways through their nodes, so segments crossing a tile without a node there can be missed if no other tile retrieves the way. Coverage also depends on OSM mapping and the availability of relation members.

## Outputs

- `outputs/day25-bruges-drawn-to-water-preview.png` is the low-resolution portrait proof. The print PNG is exported at 300 dpi, and the PDF preserves vector strokes and embeds Roboto.
- `data/day25-bruges-drawn-to-water.gpkg` contains `building_centroids`, `straight_connections`, `decorative_curves`, `waterways`, `study_frame` and `download_coverage`. Link records include building and waterway OSM IDs, the eligible class and `distance_m`.
- `data/validation.json` records feature counts, reviewed waterway classes, minimum, median and maximum distances, and the number of matches independently checked.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/portfolio) · [Back to challenge](../)
