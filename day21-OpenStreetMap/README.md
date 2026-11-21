# Day 21 – OpenStreetMap | Ávila Within the Walls

#30DayMapChallenge 2026 · OpenStreetMap · María Victoria León Parra

Ávila’s medieval wall encloses a compact historic centre in Castilla y León, Spain. This illustrated cutout follows the enclosure, with the wall and its towers forming the silhouette against the white page.

![Ávila Within the Walls](outputs/day21-avila-within-the-walls.png)

[Print PNG](outputs/day21-avila-within-the-walls.png) · [Vector PDF](outputs/day21-avila-within-the-walls.pdf)

[Previous rectangular PNG](outputs/day21-avila-within-the-walls-rectangular.png) · [Previous rectangular PDF](outputs/day21-avila-within-the-walls-rectangular.pdf)

## Tools

Python 3.12, Prettymaps 1.4.2, OSMnx, GeoPandas, Shapely, pyproj and Matplotlib. The print layout uses the bundled Roboto Regular and Bold faces.

## Workflow

1. Load a rectangular OpenStreetMap extract around the centre. Inspect nodes, ways and relations for historic city-wall, wall, retaining-wall and gate tags, and check the monument’s name and Wikidata identifier.
2. Separate the single mapped wall footprint from general building footprints. Reproject from geographic WGS 84 to WGS 84 / UTM zone 30N (EPSG:32630), where the local coordinates and street buffers are in metres.
3. Locate the inner ring of the verified wall and cathedral footprints with a temporary 4 m buffer. Reverse that inset on the town side, subtract the masonry and retain the mapped cathedral footprint in the mask. Clip every contextual layer to this enclosure and draw the original wall and towers above it at full stroke width.
4. Adapt the tutorial’s layer-and-style approach to the cached data. Use Prettymaps to buffer street centrelines by class and draw the polygonal layers. Outline individual buildings in charcoal and assign their decorative stone, terracotta, ochre, sage and muted blue fills by hashing each OSM identifier. Cream streets and a dark brown wall with a pale keyline stay distinct from the building palette.
5. Fit the cutout to a 300 mm wide white page at equal metric aspect, with no rotation. Calculate page height from the projected proportions and the space for the title, legend, scale bar and centred footer. Include OSM attribution on the footer line. Derive the scale bar from the projected view width and compute true north from a WGS 84 geodesic at the arrow’s position.

## Local data and reproduction

From this day’s directory, in an activated Python 3.12 virtual environment, run:

```sh
python -m pip install -r requirements.txt
python -m pip install --no-deps prettymaps==1.4.2
python make_map.py
```

The second command bypasses the published Prettymaps constraints on NumPy and OSMnx. The requirements file supplies the Python 3.12 dependencies used by the map, including OSMnx 2 for reading the cached XML extract.

The compressed `data/avila_*.osm.bz2` is the bundled snapshot for the default bbox. It makes routine runs offline. If the cache for the configured bbox is missing, the script fetches and stores a fresh extract. The download bbox, enclosure buffer, view padding, street widths, palette, strokes and export formats are grouped near the top of `make_map.py`.

## Sources and inspiration

- **Geometries.** OpenStreetMap API 0.6, retrieved 19 November 2026 for 4.711–4.690° W and 40.649–40.665° N. © OpenStreetMap contributors, ODbL. [Map extract](https://api.openstreetmap.org/api/0.6/map?bbox=-4.711,40.649,-4.690,40.665) · [Copyright and licence](https://www.openstreetmap.org/copyright)
- **Inspiration.** Marcelo Prates’ official tutorial supplied the approach of styling OSM layers separately, varying street widths by class and using a building palette. The supplied Prettymaps image informed the white background, irregular silhouette and outlined features. [Prettymaps tutorial](https://marceloprates.github.io/prettymaps/tutorial/)

## Notes and limitations

- OSM way `45976728` carries `barrier=city_wall`, `historic=citywalls`, `building=yes` and `wikidata=Q3050235`. The closed way contains 1,029 node references including the repeated closing node, and every referenced node is in the extract. No relation in the extract lists it as a way member. The map draws the footprint once, with separate stroke and fill styling. [Murallas de Ávila in OpenStreetMap](https://www.openstreetmap.org/way/45976728)
- The east-side wall highlight breaks beside the cathedral. OSM maps the cathedral as a separate building footprint, which appears in the building layer. Gate points and other local barriers are outside the wall layer. The audit verifies coverage in the extract. Individual masonry and gate alignments have no independent field check. [Catedral de Ávila in OpenStreetMap](https://www.openstreetmap.org/way/50694497)
- The clipping edge is derived from the mapped structures and can end contextual features at the enclosure. The temporary buffer is used only to identify the interior. The wall and cathedral keep their original shapes, including the breaks between them. Street widths are graphic conventions and building colours carry no building-use information.

## Outputs

- `outputs/day21-avila-within-the-walls.png` at 300 dpi.
- `outputs/day21-avila-within-the-walls.pdf` with vector geometry and embedded Roboto fonts.
- Both use a 300 mm wide page with 10 mm outer margins and a height calculated from the map proportions (236.02 mm with the bundled data). The `-rectangular` PNG and PDF preserve the previous 1:4,600 composition for comparison.

## Author

María Victoria León Parra
