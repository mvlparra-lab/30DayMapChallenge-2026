# # Day 21 | Ávila Within the Walls
#
# **Author:** María Victoria León Parra
# **Challenge:** #30DayMapChallenge 2026 · Day 21 · OpenStreetMap
# **Purpose:** Show the medieval wall and the contrast between the streets
# and building fabric inside and outside the historic centre of Ávila.
# **Data:** OpenStreetMap API 0.6, © OpenStreetMap contributors (ODbL).
# **Inspiration:** [Marcelo Prates' Prettymaps tutorial](https://marceloprates.github.io/prettymaps/tutorial/).
# **Workflow:** Project the cached OSM data, derive a cutout from the wall and
# cathedral footprints, then style and export the print map with Prettymaps.
# **Run:** Install the dependencies as described in README.md, then run
# `python make_map.py`. The bundled OSM cache enables offline reproduction.

from __future__ import annotations

import bz2
from hashlib import blake2b
from pathlib import Path
from tempfile import NamedTemporaryFile
from xml.etree import ElementTree

import matplotlib
import osmnx as ox
import requests
from pyproj import Geod, Transformer
from shapely import make_valid, orient_polygons, union_all
from shapely.geometry import Polygon, box

matplotlib.use("Agg")
from matplotlib import font_manager, pyplot as plt
from matplotlib.collections import PatchCollection
from matplotlib.ft2font import FT2Font
from matplotlib.legend_handler import HandlerTuple
from matplotlib.patches import Patch
from prettymaps.draw import PolygonPatch, graph_to_shapely


# Configuration
ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
OUTPUTS = ROOT / "outputs"
STEM = "day21-avila-within-the-walls"
TITLE = "Day 21 | Ávila Within the Walls"
FOOTER = (
    "#30DayMapChallenge | 2026 | Day – 21 | OpenStreetMap | "
    "Ávila Within the Walls | Map by María Victoria León Parra"
)
ATTRIBUTION = "© OpenStreetMap contributors"
PAGE_WIDTH_MM, MARGIN_MM, DPI = 300, 10, 300
EXTRA_VERTICAL_GAP_MM = 5
EXPORT_FORMATS = ("png", "pdf")

# WGS 84 / UTM zone 30N keeps map coordinates in metres across Ávila.
LOCAL_CRS = "EPSG:32630"
TO_LOCAL = Transformer.from_crs(4326, LOCAL_CRS, always_xy=True)
TO_WGS84 = Transformer.from_crs(LOCAL_CRS, 4326, always_xy=True)
GEOD = Geod(ellps="WGS84")
# Locate the interior ring with a small temporary buffer, then undo its inset.
ENCLOSURE_JOIN_M = 4
VIEW_PADDING_M = 4
MIN_ENCLOSED_AREA_M2 = 250_000
OSM_BBOX = (-4.711, 40.649, -4.690, 40.665)  # west, south, east, north
BBOX_QUERY = ",".join(str(value) for value in OSM_BBOX)
CACHE = DATA / f"avila_{BBOX_QUERY.replace(',', '_')}.osm.bz2"
WALL_ID = ("way", 45976728)
CATHEDRAL_ID = ("way", 50694497)

GREEN_TAGS = {
    "landuse": ["grass", "meadow", "forest", "orchard", "allotments", "vineyard"],
    "leisure": ["park", "garden", "nature_reserve"],
    "natural": ["wood", "scrub", "grassland"],
}
# Prettymaps buffers street centrelines by these half-widths in projected metres.
ROAD_WIDTHS = {
    "primary": 5.1, "secondary": 4.8, "tertiary": 4.3, "residential": 3.0,
    "unclassified": 2.8, "living_street": 2.6, "pedestrian": 2.3,
    "service": 1.8, "track": 1.6, "cycleway": 1.35, "footway": 1.15,
    "path": 1.05, "steps": 1.05,
}
TAGS = {
    **GREEN_TAGS,
    "natural": [*GREEN_TAGS["natural"], "water"],
    "waterway": ["riverbank"],
    "building": True,
    "highway": list(ROAD_WIDTHS),
    "barrier": ["city_wall", "wall", "retaining_wall"],
    "historic": ["citywalls", "city_wall", "city_gate"],
    "wikidata": ["Q3050235"],
}
COLORS = {
    "paper": "#ffffff", "ground": "#f3ead8", "ink": "#303531",
    "accent": "#684838", "green": "#a8b88a", "water": "#91b8c2",
    "road": "#fff9e9", "road_edge": "#484740",
    "wall": "#683a2b", "wall_edge": "#35251e", "wall_keyline": "#faf0d9",
}
BUILDING_PALETTE = (
    "#dfc9ad", "#d9bfa4", "#ecd8bd", "#d7a070", "#d1ab62",
    "#c67e61", "#b96950", "#acb79b", "#8faeb5", "#e2b092",
)
LINE_WIDTHS = {"green": 0.68, "water": 0.5, "roads": 0.57,
               "buildings": 0.48, "wall_edge": 1.1, "wall_keyline": 3.1}


def get_extract():
    """Reuse the bbox-specific cache or download and atomically cache an OSM extract."""
    if CACHE.is_file():
        return CACHE

    DATA.mkdir(parents=True, exist_ok=True)
    with requests.get(
        "https://api.openstreetmap.org/api/0.6/map",
        params={"bbox": BBOX_QUERY},
        headers={"User-Agent": "30DayMapChallenge-Avila/1.0 (static cartography)"},
        timeout=(15, 90),
    ) as response:
        response.raise_for_status()
    root = ElementTree.fromstring(response.content)
    if root.tag != "osm" or root.find("bounds") is None or root.find("way") is None:
        raise ValueError("The OSM server did not return a map extract.")

    with NamedTemporaryFile(dir=DATA, suffix=".bz2", delete=False) as temporary:
        temporary_path = Path(temporary.name)
    try:
        with bz2.open(temporary_path, "wb", compresslevel=9) as compressed:
            compressed.write(response.content)
        temporary_path.replace(CACHE)
    finally:
        temporary_path.unlink(missing_ok=True)
    return CACHE


def make_cutout(wall, cathedral):
    """Find the interior of the verified wall and cathedral footprints."""
    masonry = wall.union(cathedral)
    joined = masonry.buffer(ENCLOSURE_JOIN_M)
    interiors = [Polygon(ring) for ring in joined.interiors] if joined.geom_type == "Polygon" else []
    if not interiors or max(p.area for p in interiors) < MIN_ENCLOSED_AREA_M2:
        raise ValueError("The wall and cathedral no longer produce the expected enclosure.")
    # Restore the inset on the town side only. The cathedral defines the
    # enclosure at its eastern edge and retains its independently mapped shape.
    interior = max(interiors, key=lambda polygon: polygon.area)
    cutout = interior.buffer(ENCLOSURE_JOIN_M).difference(masonry).union(cathedral)
    bounds = cutout.union(wall).bounds
    if not box(*OSM_BBOX).covers(box(*TO_WGS84.transform_bounds(*bounds))):
        raise ValueError("The enclosure exceeds the extract. Enlarge OSM_BBOX.")
    return cutout


def get_layers():
    """Read the cached OSM features and select layers for the cutout."""
    features = ox.features_from_xml(get_extract(), tags=TAGS).to_crs(LOCAL_CRS)
    # Some OSM tags may be absent from a freshly downloaded snapshot.
    columns = features.columns.union(["building", "highway", "natural", "waterway"])
    features = features.reindex(columns=columns)
    if WALL_ID not in features.index or CATHEDRAL_ID not in features.index:
        raise ValueError("The audited wall or cathedral way is missing from the OSM extract.")
    footprint = features.loc[WALL_ID].geometry
    cathedral = features.loc[CATHEDRAL_ID].geometry
    if not all(shape.is_valid and shape.area > 0 for shape in (footprint, cathedral)):
        raise ValueError("The wall and cathedral must be valid mapped areas.")
    cutout = make_cutout(footprint, cathedral)
    print(f"Wall way {WALL_ID[1]}: {footprint.geom_type}, {footprint.area:,.0f} m2")

    context = features.drop(index=WALL_ID)
    context = context[context.intersects(cutout.buffer(max(ROAD_WIDTHS.values())))]
    polygons = context[context.geom_type.isin(["Polygon", "MultiPolygon"])].copy()
    polygons.geometry = polygons.geometry.make_valid()
    green = polygons.index[:0]
    for tag, values in GREEN_TAGS.items():
        if tag in polygons:
            green = green.union(polygons.index[polygons[tag].isin(values)])

    roads = context[context.highway.isin(ROAD_WIDTHS) & context.geom_type.isin(
        ["LineString", "MultiLineString"]
    )]
    # Buffer only source centrelines. Polygonal pedestrian areas retain their mapped shape.
    road_areas = polygons[polygons.highway.eq("pedestrian")].geometry
    return {
        "cutout": cutout,
        "green": union_all(polygons.loc[green].geometry),
        "water": union_all(polygons.loc[
            polygons.natural.eq("water") | polygons.waterway.eq("riverbank")
        ].geometry),
        "roads": graph_to_shapely(roads.copy(), ROAD_WIDTHS).union(union_all(road_areas)),
        "buildings": polygons.loc[
            polygons.building.notna() & polygons.building.ne("no")
        ].geometry.sort_index(),
        "wall": footprint,
    }


def draw_layer(panel, geometry, fill, edge, width, order, clip=None):
    """Render polygonal OSM geometry with Prettymaps, preserving holes."""
    shape = orient_polygons(make_valid(geometry))
    if shape.area > 0:
        patch = PolygonPatch(shape, fc=fill, ec=edge, lw=width, zorder=order,
                             joinstyle="round")
        panel.add_patch(patch)
        if clip is not None:
            patch.set_clip_path(clip)
        return patch


def building_color(element):
    """Assign a decorative colour from the stable OSM feature identifier."""
    key = f"{element[0]}/{element[1]}".encode("ascii")
    index = int.from_bytes(blake2b(key, digest_size=8).digest(), "big")
    return BUILDING_PALETTE[index % len(BUILDING_PALETTE)]


def add_orientation(axis, frame):
    """Draw true north and choose a round metric distance to fit the map width."""
    west, south, east, north = frame.bounds
    width, height = east - west, north - south
    ink, accent = COLORS["ink"], COLORS["accent"]

    # Convert a short true-north geodesic to the projected map at the arrow's position.
    arrow_start = east - 0.041 * width, north - 0.069 * height
    lon, lat = TO_WGS84.transform(*arrow_start)
    lon_n, lat_n, _ = GEOD.fwd(lon, lat, 0, 0.058 * height)
    arrow_end = TO_LOCAL.transform(lon_n, lat_n)
    axis.annotate("", arrow_end, xytext=arrow_start, zorder=9,
                  arrowprops={"arrowstyle": "-|>", "color": ink, "lw": 1.4,
                              "mutation_scale": 15})
    axis.text(arrow_end[0], arrow_end[1] + height * 0.012, "N",
              ha="center", va="bottom", color=ink, fontsize=11, weight="bold",
              zorder=9)

    # Use projected eastings in metres and place the bar below the map panel.
    scale = max(length for length in (10, 25, 50, 100, 200, 250, 500, 1000)
                if length <= max(10, width * 0.22))
    x, y = east - scale - width * 0.024, south - height * 0.048
    for start, end, color in ((0, scale / 2, ink), (scale / 2, scale, accent)):
        axis.plot([x + start, x + end], [y, y], color=color, linewidth=2.4,
                  solid_capstyle="butt", clip_on=False, zorder=9)
    for distance, label in ((0, "0"), (scale / 2, f"{scale / 2:g}"),
                            (scale, f"{scale:g} m")):
        axis.plot([x + distance] * 2, [y - height * 0.003, y + height * 0.003],
                  color=ink, linewidth=0.7, clip_on=False, zorder=9)
        axis.text(x + distance, y + height * 0.008, label, color=ink,
                  ha="center", va="bottom", fontsize=9)


def compose(layers):
    """Apply the centred Roboto title and footer used in the Day 20 print layout."""
    for font in sorted(DATA.glob("Roboto-*.ttf")):
        font_manager.fontManager.addfont(font)
    plt.rcParams.update({"font.family": "Roboto", "pdf.fonttype": 42})
    paper, ink = COLORS["paper"], COLORS["ink"]
    title_color = ink
    cutout = layers["cutout"]
    west, south, east, north = cutout.union(layers["wall"]).bounds
    frame = box(west - VIEW_PADDING_M, south - VIEW_PADDING_M,
                east + VIEW_PADDING_M, north + VIEW_PADDING_M)
    west, south, east, north = frame.bounds
    aspect = (east - west) / (north - south)
    # Size the page in millimetres from the geographic aspect and text bands.
    panel_width_mm = PAGE_WIDTH_MM - 2 * MARGIN_MM
    panel_height_mm = panel_width_mm / aspect
    panel_bottom_mm = MARGIN_MM + 18 + EXTRA_VERTICAL_GAP_MM
    page_height_mm = panel_bottom_mm + panel_height_mm + MARGIN_MM + 15 + EXTRA_VERTICAL_GAP_MM
    figure = plt.figure(figsize=(PAGE_WIDTH_MM / 25.4, page_height_mm / 25.4), facecolor=paper)
    margin = MARGIN_MM / PAGE_WIDTH_MM
    panel_height = panel_height_mm / page_height_mm
    panel_bottom = panel_bottom_mm / page_height_mm
    panel = figure.add_axes([margin, panel_bottom, panel_width_mm / PAGE_WIDTH_MM, panel_height])
    panel.set_axis_off()

    clip = draw_layer(panel, cutout, COLORS["ground"], "none", 0, 0)
    # The shared vector clip avoids drawing artificial feature edges where the
    # mask crosses a building, park or street.
    draw_layer(panel, layers["green"], COLORS["green"], ink, LINE_WIDTHS["green"], 1, clip)
    draw_layer(panel, layers["water"], COLORS["water"], ink, LINE_WIDTHS["water"], 2, clip)
    draw_layer(panel, layers["roads"], COLORS["road"], COLORS["road_edge"],
               LINE_WIDTHS["roads"], 3, clip)
    buildings = layers["buildings"]
    footprints = [(element, shape) for element, shape in buildings.items() if shape.area > 0]
    building_patches = PatchCollection(
        [PolygonPatch(orient_polygons(shape)) for _, shape in footprints],
        facecolors=[building_color(element) for element, _ in footprints],
        edgecolors=ink, linewidths=LINE_WIDTHS["buildings"], joinstyle="round", zorder=4,
    )
    panel.add_collection(building_patches)
    building_patches.set_clip_path(clip)
    draw_layer(panel, layers["wall"], "none", COLORS["wall_keyline"],
               LINE_WIDTHS["wall_keyline"], 5, clip)
    draw_layer(panel, layers["wall"], COLORS["wall"], COLORS["wall_edge"],
               LINE_WIDTHS["wall_edge"], 6)

    panel.set(xlim=(west, east), ylim=(south, north), aspect="equal", xticks=[], yticks=[])
    add_orientation(panel, frame)

    figure.text(0.5, 1 - MARGIN_MM / page_height_mm, TITLE, color=title_color,
                size=31, weight="bold", ha="center", va="top")
    handles = [
        Patch(facecolor=COLORS["wall"], edgecolor=COLORS["wall_edge"]),
        tuple(Patch(facecolor=BUILDING_PALETTE[i], edgecolor=ink) for i in (0, 5, 8)),
        Patch(facecolor=COLORS["road"], edgecolor=COLORS["road_edge"]),
        Patch(facecolor=COLORS["green"], edgecolor=ink),
    ]
    figure.legend(handles, ["Medieval wall", "Buildings", "Streets and paths", "Green space"],
                  handler_map={tuple: HandlerTuple(ndivide=None, pad=0.12)},
                  loc="center left", bbox_to_anchor=(margin, panel_bottom - 0.033 * panel_height),
                  ncol=len(handles),
                  frameon=False, borderaxespad=0, labelcolor=ink, fontsize=10,
                  handlelength=2.2, columnspacing=1.45)
    # Share one centred footer line and keep it inside the print margin.
    footer_size = 9.5
    font = FT2Font(str(DATA / "Roboto-Regular.ttf"))
    descent_mm = -font.descender / font.units_per_EM * footer_size * 25.4 / 72
    figure.text(0.5, (MARGIN_MM + descent_mm) / page_height_mm,
                f"{FOOTER} | {ATTRIBUTION}", color=title_color,
                size=footer_size, ha="center", va="baseline")
    return figure


def main():
    """Load data, compose the map and export the agreed print formats."""
    figure = compose(get_layers())
    OUTPUTS.mkdir(exist_ok=True)
    for extension in EXPORT_FORMATS:
        output = OUTPUTS / f"{STEM}.{extension}"
        options = {"metadata": {"Title": TITLE, "Author": "María Victoria León Parra"}}
        figure.savefig(output, dpi=DPI, **options)
        print(f"Saved {output}")
    plt.close(figure)


if __name__ == "__main__":
    main()
