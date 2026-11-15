# Day 15 | The Shape of a Cave

Inside out · 30DayMapChallenge 2026

M19 is a surveyed cave on Slovenia’s Migovec Plateau (Slovenian cave register no. 8285). The map shows the reconstructed empty space beneath its entrance as an orthographic view, with a matching true-north plan. [Final map](output/day15_inside_out_cave.png) · [Executed notebook](day15_inside_out_cave.ipynb)

## Tools

[Therion 6.4.1](https://therion.speleo.sk/download.php) built the walls and station exports. Python 3.11+, Jupyter, NumPy, Matplotlib, Pillow and the bundled Roboto fonts compose and verify the map. This survey compiles with Therion’s internal station processing. A portable build may mention that Cavern is absent in its startup check.

## Workflow

1. The Imperial College Caving Club’s live M19 tutorial describes the TopoDroid files but its download link has no destination. The club’s survey repository carries the matching 31 July 2018 M19 dataset with usable plan wall scraps, heights, splays and entrance metadata, so the project uses the maintained files from that archive.
2. As in the tutorial, Therion reads a centreline `.th` and wall drawings `.th2`. The companion wall-editing guide calls for connected wall ends and interior-facing wall orientations so Therion can build the 3D walls. This build uses the archive’s maintained plan scraps and height annotations as drawn. Therion processed all seven plan scraps with 0.08% average plan distortion.
3. The project fixes station 25 as the local origin and corrects the original magnetic bearings to true north. Therion exports a native Loch model, DXF faces and the station table.
4. Python renders the DXF passage faces, trimming the unsupported extension above the entrance datum. It shows the surveyed connection between stations 21 and 22 as a dash across the break in the wall mesh. It colors each face by the mean vertical distance of its vertices below station 25 and shades the oblique view for relief. The plan projects the same faces onto the east–north plane. Both views mark the same station. The station 25 label identifies the 0 m reference used for passage depth.
5. The square figure is 300 × 300 mm with Roboto type and a 5 mm footer margin. The inset scale comes from its equal-aspect metric transform. The full depth and surveyed-link legend sits below the plan scale. At nominal print size, its 10 m bar is 23.25 mm long (approximately 1:430).

## Local data

Install the Python requirements and Therion 6.4.1. Put the Therion CLI on PATH or set `THERION_EXE` to the full path of its executable. Open the notebook from this folder and choose **Run All** to rebuild the survey and render the map.

```sh
python -m pip install -r requirements.txt
jupyter notebook day15_inside_out_cave.ipynb
```

The notebook has `REBUILD_MODEL = True`. Set it to `False` to render directly from the bundled model. The equivalent commands for a fresh build are below.

```sh
therion -l model/therion.log thconfig
python render_map.py
```

The compile writes `model/m19.lox`, `model/m19.dxf` and `model/m19.sql`. The renderer writes the final 3543 × 3543 px PNG straight from the layout at 300 dpi. Pass `--preview` to render only the 1300 × 1300 px preview. The survey inputs, rebuilt model and fonts are bundled. Only the software dependencies need external installation.

The notebook, source inputs, portable model files and final PNG are the retained deliverables. The regenerated preview, build log, runtime and caches are local files listed in `.gitignore`.

## Sources and inspiration

- **Survey.** ICCC and JSPDT, *Survey Data for the Tolminski Migovec Cave Exploration project*, 2024. M19 was surveyed by Tanguy Racine, Celia Tinsley and Louise Ranken on 31 July 2018. The exact snapshot is [`data/M_caves/M19/` at `f16d4f4e7bf848a7169c6635f649c06d4d46bbbc`](https://github.com/iccaving/migovec-survey-data/tree/f16d4f4e7bf848a7169c6635f649c06d4d46bbbc/data/M_caves/M19). The archive declares copyright ICCC / JSPDT 1974–2024 and licenses the survey under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). The adapted survey and derived model and maps are shared under those same terms. [Dataset DOI](https://doi.org/10.5281/zenodo.10813021) · [Pinned license statement](https://github.com/iccaving/migovec-survey-data/blob/f16d4f4e7bf848a7169c6635f649c06d4d46bbbc/README.md#licence)
- **Files.** `data/M19.th` contains the centreline and splays. The only edits are the local entrance fix and magnetic declination. The compiled plan sources are `M19-15p.th2` and `M19-234p.th2`, with `M19-1s.th2` for extended elevation. The included drawings match the pinned files.
- **Reference.** Survey lengths are in metres and bearings and inclinations are in degrees. The map uses local east, true north and up in metres, with station 25 at (0, 0, 0) and no EPSG code. The club’s layout guide gives the entrance as 46.253034° N, 13.760225° E, 1860 m. The coordinates are used to evaluate declination (+3.677767° east) for 2018-07-31 at 1.86 km using WMM2015v2 with pygeomag 1.1.0. The map uses relative elevations throughout. [Entrance fix](https://imperialcaving.com/wiki/layout-basic) · [WMM2015v2 coefficients](https://github.com/boxpet/pygeomag/blob/v1.1.0/pygeomag/wmm/WMM_2015v2.COF)
- **Type.** Google’s Roboto Regular, Bold and Black are bundled with their Apache 2.0 license. [Roboto source](https://github.com/googlefonts/roboto/tree/main/src/hinted)

- **Tutorial.** Imperial College Caving Club’s workflow starts with the TopoDroid centreline and wall drawings and builds a Therion model from connected passage outlines. For *Inside out*, the oblique view isolates the cave void and the brown palette encodes depth from station 25. The matching plan gives the volume a north-up reference. [M19 Tutorial](https://imperialcaving.com/wiki/m19-tutorial) · [Editing the TH2](https://imperialcaving.com/wiki/editing-the-th2) · [Wall guide mirror](https://github-wiki-see.page/m/iccaving/icccwiki/wiki/EditingTheTh2)

## Entrance and gap checks

- **Elevation across the survey.** Station 25 is the highest of all 28 named stations at 0.00 m, and the lowest is −61.54 m. The only positive endpoint among 354 splays is +0.01 m, from a second 5.64 m sight along the same bearing as the shot to station 25. Its inclination differs by 0.1°, consistent with a repeat sight to the entrance. The first inward leg drops 4.69 m. The extended drawing shows some rock and debris outlines above the datum at the open entrance depression, with no separate passage section or surveyed centerline above 0 m. The +13.34 m extension in the plan-derived mesh remains trimmed at station 25 with an open cut. [Side views](model/entrance_side_check.png) · [Source elevation detail](model/extended_elevation_check.png) · [ICCC expedition report](https://www.imperialcaving.com/old/slovenia/report/1994.php)
- **Gap below the entrance.** The 21–22 connection is a measured 5.02 m shot. Station 22 is in plan scrap M19-1p and station 21 is in scrap M19-6p. The wall faces stop short across that seam in two side projections as well as in the oblique view. The revision draws the shot behind the passage faces, leaving a short dash visible across the break.

## Notes

- Therion reconstructs surfaces between surveyed outlines, splays and spot heights. Sparse vertical measurements and scrap boundaries can produce gaps, tall facets and uncertain roof profiles. The mesh is a simplified representation of the surveyed cave. The raw DXF contains 940 triangles and spans −61.23 to +13.34 m relative to the entrance. The display mesh has 954 triangles after clipping and triangulation at 0 m. The raw Therion exports retain the original model.
- The inset and oblique view share the same passage mesh. The entrance markers come from station 25 in the Therion station export. Depth is elevation difference from the entrance, with a 0–65 m ramp extending to the next 5 m increment beyond the deepest vertex. The oblique view uses equal scale in all directions.
- The final PNG was inspected for label separation, the amber station 25 markers, the north arrow and the 0 / 5 / 10 m scale. The re-rendered preview is pixel-identical to the approved preview. The renderer verified Roboto Black 30 pt for the centered title, Roboto Bold 18 pt for M19 and Roboto Regular 10 pt for the centered footer. The full-resolution raster places the footer's visible text 5.0 mm above the edge, with 13.3 mm of clear space above it.
- **Print at actual size.** The 10 m plan bar measures 23.25 mm on the 300 × 300 mm sheet, approximately 1:430. The final file is 3543 × 3543 px with 300 dpi metadata.

## Author

María Victoria León Parra
