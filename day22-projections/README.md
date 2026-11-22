# Day 22 – Projections | One World, Five Perspectives

#30DayMapChallenge 2026 · Projections · María Victoria León Parra

How does the same world change when a map preserves area, preserves local angles, or puts the ocean at the center? The loop moves from Web Mercator through three equal-area projections to Spilhaus, then returns to Web Mercator.

![One World, Five Perspectives in Spilhaus](outputs/day22-one-world-five-perspectives.png)

[Looping GIF](outputs/day22-one-world-five-perspectives.gif) · [MP4](outputs/day22-one-world-five-perspectives.mp4) · [Still PNG](outputs/day22-one-world-five-perspectives.png)

## Tools

Python 3.12, GeoPandas, Pyogrio, Shapely, NumPy, pyproj with PROJ 9.6 or newer, Pillow and FFmpeg. The layout uses the bundled Roboto Regular and Bold faces, as in Days 20 and 21.

## Workflow

1. Read the Natural Earth country polygons in WGS 84, repair invalid source geometry and keep the polygonal parts.
2. Apply the five registered or documented PROJ definitions and fit each footprint into the same map box with one scale for both axes.
3. Inverse-project each supersampled map pixel to longitude and latitude, then look up its Natural Earth polygon. A forward round-trip check rejects samples outside the projection footprint, including the gaps between Goode's lobes. The lookup keeps split features on their proper sides of the antimeridian and interruption seams without connecting projected vertices across a cut.
4. Hold each map for 2.4 seconds and fade through the paper background over 1.2 seconds, including the return from Spilhaus to Web Mercator. The title and footer stay visible. The projection caption fades with its map and keeps the same position. Fading also handles the change in polar coverage between Web Mercator and Equal Earth. Intermediate frames are visual blends.

## Local data and reproduction

The Natural Earth 1:110m Admin 0 Countries v5.1.1 archive and Roboto fonts are bundled in `data/`. Day 07 uses the same Natural Earth layer but downloads it at runtime. Day 22 runs offline after the Python dependencies are installed.

From this day's directory in a Python 3.12 virtual environment, run:

```sh
python -m pip install -r requirements.txt
python make_map.py
```

The script prepares the five panels before encoding. It caches those panels in the operating system's temporary directory and reuses them when the script, source archive and projection library versions match.

## Sources and inspiration

- **Country polygons.** [Natural Earth 1:110m Admin 0 Countries](https://www.naturalearthdata.com/downloads/110m-cultural-vectors/110m-admin-0-countries/) · [Source archive](https://naturalearth.s3.amazonaws.com/110m_cultural/ne_110m_admin_0_countries.zip)
- **Tutorial.** Milan Janosov scales countries around their centroids to illustrate the size distortion in Web Mercator. This animation adapts that comparison by rendering the original geographic polygons in five projections. [Web Mercator vs True Size](https://www.youtube.com/watch?v=3TfDe_LdcYQ)
- **Projection definitions.** [Web Mercator](https://proj.org/en/stable/operations/projections/webmerc.html) · [Equal Earth](https://proj.org/en/stable/operations/projections/eqearth.html) · [Mollweide](https://proj.org/en/stable/operations/projections/moll.html) · [Interrupted Goode Homolosine](https://proj.org/en/stable/operations/projections/igh.html) · [Spilhaus in PROJ](https://proj.org/en/stable/operations/projections/spilhaus.html) · [Esri's Spilhaus Ocean Map in a Square](https://content.esri.com/esripress/books/gis-for-science-tech-showcase/files/basic-html/page29.html)

## Notes and limitations

- **Web Mercator (EPSG:3857)** uses spherical Mercator math and greatly enlarges high latitudes. The square web-map extent stops at approximately 85.0511° N and S. Antarctica remains visible up to the southern cutoff. The four other views use the full latitude range and retain Antarctica.
- **Equal Earth** preserves relative area. Its rounded outline comes with changes in shape and scale across the map.
- **Mollweide** preserves relative area on a sphere. The elliptical outline stretches shapes toward the sides.
- **Interrupted Goode Homolosine** combines Sinusoidal and Mollweide to preserve area and uses cuts to reduce distortion over land. The interruptions split the oceans and parts of Antarctica.
- **Spilhaus (ESRI:54099)** puts the world ocean at the center. Its oblique Adams Square II construction preserves local angles away from the corners and can greatly enlarge areas near the perimeter. Geographic features that meet a square edge continue on another edge. Where PROJ's direct inverse fails near a corner, the script solves against the registered forward transform. At the two singular corners, it uses a uniform land fill for the remaining samples after confirming that their geographic estimates cluster inside a single country polygon.
- The source is generalized for world maps. Small islands may fall below the output pixel size. There is no single distance scale or north arrow for the sequence because scale and the orientation of geographic north vary across the views.

## Outputs

- `outputs/day22-one-world-five-perspectives.gif` loops indefinitely and uses a shared palette and frame differences to reduce file size.
- `outputs/day22-one-world-five-perspectives.mp4` contains one complete cycle in H.264.
- `outputs/day22-one-world-five-perspectives.png` shows the Spilhaus view.
- All three use a fixed 1200 × 1356 px portrait canvas. The 300 mm layout width gives the map box 10 mm (40 px) side margins, with a small additional clearance around each projection footprint. Each animation cycle lasts 18 seconds.

## Author

María Victoria León Parra
