# Day 24 | The Streets That Connect Jaén

#30DayMapChallenge 2026 · Network · María Victoria León Parra

The street network of Jaén, Spain, links the historic centre, the surrounding neighbourhoods and the main approaches to the city. This map shows which street segments lie on the most shortest paths by distance across that network.

![The Streets That Connect Jaén](outputs/day24-the-streets-that-connect-jaen.png)

[Print PNG](outputs/day24-the-streets-that-connect-jaen.png) · [Vector PDF](outputs/day24-the-streets-that-connect-jaen.pdf) · [GeoPackage](outputs/day24-the-streets-that-connect-jaen.gpkg)

## Tools

Python 3.12, OSMnx, NetworkX, GeoPandas, NumPy, Matplotlib, Shapely, pyproj and Pyogrio. The pinned versions are in `requirements.txt`. The print layout uses the bundled Roboto Regular and Bold faces and follows Days 20 and 21 for page size, margins, typography and exports.

## Workflow

1. Centre the print frame on the continuous urban area of Jaén. The frame is 4.7 km wide and about 4.0 km high. Add a 1 km buffer on every side to include nearby connections that could otherwise disappear at the map edge.
2. Use OSMnx’s `drive` network and retain the largest weakly connected component. In the simplified graph, nodes represent junctions and dead ends, and edges follow street centrelines between them. Convert the directed multigraph to an undirected multigraph to allow travel in both directions for the structural analysis. OSMnx removes reciprocal duplicates and retains geometrically distinct parallel streets.
3. Project to WGS 84 / UTM zone 30N (EPSG:32630). Measure each full centreline in projected metres and pass that positive length as the NetworkX shortest-path weight. Compute exact, normalized edge betweenness on the buffered graph using all graph nodes, with no sampling or seed. Each unordered node pair contributes the fraction of its shortest paths that traverse an edge. For parallel edges between the same two nodes, NetworkX uses the shortest edge length for routing and shares the pair’s edge credit evenly among ties at that length. Longer parallels get zero credit.
4. Clip the drawing to the print frame after scoring. Use the same sequential colour and width order for every visible edge, with darker, wider strokes for higher centrality. The display position is `log1p(score / median) / log1p(maximum / median)`, using the positive median and maximum of the visible scores. The legend shows the original normalized scores as percentages at log-spaced positions. The scale bar measures 500 m at the printed map scale, and the arrow points to true north.

## Local data and reproduction

From this day’s directory, in an activated Python virtual environment, run:

```sh
python -m pip install -r requirements.txt
python make_map.py
```

The compressed `data/jaen-*.graphml.gz` is the reusable street-network snapshot for the default extent. The script reuses both that snapshot and the scored GeoPackage when its analysis signature matches. Removing the GeoPackage recomputes the centrality offline from the graph. If the graph cache is absent, the script downloads a new snapshot through OSMnx’s Overpass workflow and caches the responses in `data/overpass-cache/`. The frame, buffer, network type and print settings are grouped near the top of `make_map.py`.

## Sources and inspiration

- **Street geometries.** OpenStreetMap, retrieved on 19 November 2026. The default Overpass service was unavailable during production. The bundled snapshot merges 12 OpenStreetMap API 0.6 tiles spanning 3.826–3.746° W and 37.750–37.807° N, applies the OSMnx 2.1.1 `drive` way filter, and uses OSMnx to build, simplify and trim the graph to the buffer. © OpenStreetMap contributors, ODbL. [Map API](https://wiki.openstreetmap.org/wiki/API_v0.6#Retrieving_map_data_by_bounding_box:_GET_/api/0.6/map) · [Copyright and licence](https://www.openstreetmap.org/copyright)
- **Tutorial.** The NetworkX gallery example uses OSMnx to build a street graph, weights paths by travel time and maps node betweenness. This project adapts the workflow to length-weighted edges and a printed urban map. [OpenStreetMap with OSMnx](https://networkx.org/documentation/stable/auto_examples/geospatial/plot_osmnx.html)

## Findings

The buffered graph contains 2,221 nodes and 3,085 edges, of which 2,493 intersect the print frame. Five segments of Avenida de Madrid have the highest scores among the visible edges. The highest scores 16.38%, compared with a median of 0.45% among visible edges with a positive score.

## Notes and limitations

- Centrality is structural. It does not measure traffic, pedestrian counts or street importance in other senses. Every graph node has equal weight as an origin or destination. The model ignores one-way and turn restrictions, speed, capacity and travel demand.
- OpenStreetMap coverage and the driving filter shape which streets are represented. Pedestrian-only streets and most service roads are outside the model. The analysis includes buffered streets and still depends on the choice of buffer, extent and graph simplification.
- The calculation uses floating-point centreline lengths. Routes that are nearly equal in length can receive different scores because a tie requires equal computed costs.

## Outputs

- `outputs/day24-the-streets-that-connect-jaen.png` at 300 dpi and the corresponding vector `.pdf` with embedded Roboto fonts. Both use a 300 × 300 mm page with 10 mm map side margins and 5 mm footer clearance.
- `outputs/day24-the-streets-that-connect-jaen.gpkg` in EPSG:32630. The `street_centrality` layer contains full buffered edge geometries, OSM identifiers, node IDs and edge keys, lengths in metres and normalized raw betweenness scores. The `extents` layer contains the print frame and buffered download polygon.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/portfolio) · [Back to challenge](../)
