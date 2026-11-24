# # Day 24 – Network | The Streets That Connect Jaén
#
# **Author:** María Victoria León Parra
# **Challenge:** #30DayMapChallenge 2026 · Day 24 · Network
# **Purpose:** Map the streets that carry the most distance-weighted
# shortest paths through Jaén’s urban street network.
# **Data:** OpenStreetMap via OSMnx, © OpenStreetMap contributors (ODbL).
# **Inspiration:** [NetworkX’s OpenStreetMap with OSMnx example](https://networkx.org/documentation/stable/auto_examples/geospatial/plot_osmnx.html).
# **Workflow:** Download and cache a buffered graph, project it to UTM,
# calculate edge betweenness, then crop and export the print map.
# **Run:** Install dependencies from requirements.txt and run
# `python make_map.py` from this directory. See README.md for cache details.

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory

import geopandas as gpd
import matplotlib
import networkx as nx
import numpy as np
import osmnx as ox
import pyogrio
from pyproj import Geod, Transformer
from shapely import transform
from shapely.geometry import box

matplotlib.use("Agg")
from matplotlib import font_manager, pyplot as plt
from matplotlib.collections import LineCollection
from matplotlib.colors import LinearSegmentedColormap
from matplotlib.ft2font import FT2Font


ROOT = Path(__file__).resolve().parent
DATA, OUTPUTS = ROOT / "data", ROOT / "outputs"
AUTHOR = "María Victoria León Parra"
STEM = "day24-the-streets-that-connect-jaen"
TITLE = "Day 24  | The Streets That Connect Jaén"
FOOTER = (
    "#30DayMapChallenge | 2026 | Day – 24 | Network | "
    "The Streets That Connect Jaén | Map by María Victoria León Parra"
)
# Frame and buffer dimensions are in metres. The 1 km buffer is scored in
# full, then hidden in the print layout. The centre is (longitude, latitude).
CRS = "EPSG:32630"  # WGS 84 / UTM zone 30N
TO_UTM = Transformer.from_crs(4326, CRS, always_xy=True)
TO_WGS84 = Transformer.from_crs(CRS, 4326, always_xy=True)
CENTRE = (-3.7863, 37.7783)
WIDTH_M, BUFFER_M = 4700, 1000
NETWORK_TYPE = "drive"
SCALE_M = 500

# Match the square Roboto print layout used by Days 20 and 21.
PAGE_MM, MARGIN_MM, DPI = 300, 10, 300
MAP_BOTTOM, MAP_TOP = 0.128, 0.915
MAP_WIDTH = 1 - 2 * MARGIN_MM / PAGE_MM
MAP_HEIGHT = MAP_TOP - MAP_BOTTOM
PAPER, GROUND, INK = "#faf7f0", "#ede6d8", "#293722"
ACCENT, FRAME = "#4b5d38", "#81916f"
PALETTE = ("#9ca58b", "#85946e", "#667f4e", "#49683b", "#304e2b", "#1c3824")
MIN_WIDTH, MAX_WIDTH = 0.42, 2.05
EDGE_LAYER = "street_centrality"


def bounds():
    """Build the print frame with an equal-metre map aspect."""
    x, y = TO_UTM.transform(*CENTRE)
    height = WIDTH_M * MAP_HEIGHT / MAP_WIDTH
    frame = box(x - WIDTH_M / 2, y - height / 2, x + WIDTH_M / 2, y + height / 2)
    return frame, frame.buffer(BUFFER_M, quad_segs=8)


def load_graph(coverage):
    """Reuse the graph snapshot or download it with OSMnx's response cache."""
    query = transform(coverage, TO_WGS84.transform, interleaved=False)
    spec = f"{query.wkt}|{NETWORK_TYPE}|simplified|largest-weak-component"
    key = hashlib.sha256(spec.encode()).hexdigest()[:12]
    path = DATA / f"jaen-{key}.graphml.gz"
    if not path.exists():
        ox.settings.use_cache = True
        ox.settings.cache_folder = DATA / "overpass-cache"
        # OSMnx handles downloading, cleaning, and topology simplification.
        graph = ox.graph_from_polygon(query, network_type=NETWORK_TYPE, truncate_by_edge=True)
        with TemporaryDirectory(dir=DATA) as tmp:
            pending = Path(tmp) / path.name
            ox.io.save_graphml(graph, filepath=pending)
            pending.replace(path)
    return path


def analyse(graph_path, frame, coverage):
    """Cache exact edge betweenness and the analysis extent in a GeoPackage."""
    output = OUTPUTS / f"{STEM}.gpkg"
    digest = hashlib.sha256(graph_path.read_bytes())
    # The cache stores both polygons, so include their geometry even when
    # two print layouts use the same graph snapshot.
    digest.update(frame.wkb)
    digest.update(coverage.wkb)
    # Bump the method version when changing the scoring or output schema.
    digest.update(f"|v2|{CRS}|{nx.__version__}|{ox.__version__}".encode())
    signature = digest.hexdigest()
    if output.exists():
        metadata = pyogrio.read_info(output, layer=EDGE_LAYER)["layer_metadata"] or {}
        if metadata.get("analysis_signature") == signature:
            print("Using cached centrality.")
            return gpd.read_file(output, layer=EDGE_LAYER)

    directed = ox.io.load_graphml(graph_path)
    # One-way restrictions are ignored to model structural connectivity.
    # OSMnx removes reciprocal duplicates and preserves distinct parallels.
    network = ox.convert.to_undirected(ox.projection.project_graph(directed, to_crs=CRS))
    edges = ox.convert.graph_to_gdfs(network, nodes=False)
    lengths = edges.geometry.length
    if edges.empty or not np.isfinite(lengths).all() or (lengths <= 0).any():
        raise ValueError("The network requires finite, positive street lengths.")

    # Projected centreline lengths in metres are the shortest-path cost.
    nx.set_edge_attributes(network, lengths.to_dict(), "length_m")
    print(f"Scoring {network.number_of_nodes():,} nodes and {len(edges):,} edges exactly.", flush=True)
    scores = nx.edge_betweenness_centrality(network, normalized=True, weight="length_m")
    # MultiGraph keys distinguish parallel streets. Store each score in the
    # same orientation as the corresponding GeoDataFrame row.
    edges["betweenness"] = [
        scores[(u, v, k)] if (u, v, k) in scores else scores[(v, u, k)]
        for u, v, k in edges.index
    ]
    edges["length_m"] = lengths
    edges = edges.reset_index().reindex(
        columns=["u", "v", "key", "name", "highway", "osmid",
                 "length_m", "betweenness", "geometry"]
    )
    for field in ("name", "highway", "osmid"):
        edges[field] = edges[field].map(lambda value: json.dumps(value, ensure_ascii=False)
                                        if isinstance(value, list) else value).astype("string")
    zones = gpd.GeoDataFrame({"zone": ["print_frame", "download_buffer"]},
                             geometry=[frame, coverage], crs=CRS)
    with TemporaryDirectory(dir=OUTPUTS) as tmp:
        pending = Path(tmp) / output.name
        pyogrio.write_dataframe(edges, pending, layer=EDGE_LAYER,
                                layer_metadata={"analysis_signature": signature})
        pyogrio.write_dataframe(zones, pending, layer="extents")
        pending.replace(output)
    return edges


def add_orientation(fig, panel, frame):
    """Draw true north and a 500 m scale using projected metre coordinates."""
    west, south, east, north = frame.bounds
    x = east - 390
    y = north - 275
    lon, lat = TO_WGS84.transform(x, y)
    lon2, lat2, _ = Geod(ellps="WGS84").fwd(lon, lat, 0, 125)
    tip = TO_UTM.transform(lon2, lat2)
    backdrop = {"facecolor": GROUND, "edgecolor": "none", "pad": 1.5}
    # A small ground-coloured backing keeps the arrow readable above streets.
    panel.plot([x, tip[0]], [y, tip[1]], color=GROUND, lw=8, zorder=4,
               solid_capstyle="round")
    panel.annotate("", xy=tip, xytext=(x, y), zorder=5,
                   arrowprops={"arrowstyle": "-|>", "color": INK, "lw": 1.1,
                               "shrinkA": 0, "shrinkB": 0, "mutation_scale": 13})
    panel.annotate("N", xy=tip, xytext=(0, 5), textcoords="offset points",
                   ha="center", va="bottom", color=INK, fontsize=11, weight="bold",
                   bbox=backdrop, zorder=6)

    # The scale axes have the same horizontal metres-per-page-unit as the map.
    span = MAP_WIDTH * SCALE_M / (east - west)
    scale = fig.add_axes([1 - MARGIN_MM / PAGE_MM - span, 0.081, span, 0.012])
    scale.plot([0, SCALE_M], [0.5, 0.5], color=INK, lw=1)
    scale.vlines([0, SCALE_M / 2, SCALE_M], 0.27, 0.73, color=INK, lw=1,
                 clip_on=False)
    scale.text(0, 0.87, "0", ha="left", va="bottom", color=INK, size=9)
    scale.text(SCALE_M, 0.87, f"{SCALE_M} m", ha="right", va="bottom",
               color=INK, size=9)
    scale.set(xlim=(0, SCALE_M), ylim=(0, 1))
    scale.set_axis_off()


def compose(frame, edges):
    """Crop the scored network and encode centrality with colour and width."""
    for font in sorted(DATA.glob("Roboto-*.ttf")):
        font_manager.fontManager.addfont(font)
    plt.rcParams.update({"font.family": "Roboto", "pdf.fonttype": 42})
    fig = plt.figure(figsize=(PAGE_MM / 25.4, PAGE_MM / 25.4), facecolor=PAPER)
    margin = MARGIN_MM / PAGE_MM
    panel = fig.add_axes([margin, MAP_BOTTOM, MAP_WIDTH, MAP_HEIGHT], facecolor=GROUND)

    # Clip only the display geometry. Every visible edge keeps its full
    # buffered-network score, including edges that cross the frame.
    visible = gpd.clip(edges, frame, keep_geom_type=True).explode(index_parts=False)
    visible = visible[visible.geometry.geom_type == "LineString"].sort_values("betweenness")
    scores = visible["betweenness"].to_numpy()
    positive = scores[scores > 0]
    if not positive.size:
        raise ValueError("No streets with positive centrality intersect the frame.")
    median, vmax = np.median(positive), scores.max()
    # log1p preserves zero and opens up the lower end of the skewed scale.
    stretch = np.log1p(vmax / median)
    tone = np.log1p(scores / median) / stretch
    cmap = LinearSegmentedColormap.from_list("street_centrality", PALETTE)
    widths = MIN_WIDTH + (MAX_WIDTH - MIN_WIDTH) * tone**1.7
    panel.add_collection(LineCollection([line.coords for line in visible.geometry],
                                        colors=cmap(tone), linewidths=widths,
                                        capstyle="round", joinstyle="round"))
    west, south, east, north = frame.bounds
    panel.set(xlim=(west, east), ylim=(south, north), aspect="equal", xticks=[], yticks=[])
    for spine in panel.spines.values():
        spine.set_color(FRAME)
        spine.set_linewidth(0.6)

    fig.text(0.5, 0.967, TITLE, color=INK, size=30, weight="bold", ha="center", va="top")
    fig.text(margin, 0.112, "Edge betweenness  ·  Share of shortest paths (log-scaled colour)",
             color=INK, size=11, weight="bold", va="center")
    ramp = fig.add_axes([margin, 0.086, 0.37, 0.009])
    ramp.imshow(np.linspace(0, 1, 512)[None, :], cmap=cmap, aspect="auto",
                extent=(0, 1, 0, 1))
    ticks = np.linspace(0, 1, 5)
    ramp.set(yticks=[], xticks=ticks,
             xticklabels=[f"{value:.2g}%" for value in 100 * median * np.expm1(ticks * stretch)])
    ramp.tick_params(axis="x", length=2.5, pad=2, labelsize=9, colors=INK)
    for label, align in zip(ramp.get_xticklabels()[::4], ("left", "right")):
        label.set_ha(align)
    for spine in ramp.spines.values():
        spine.set_visible(False)

    add_orientation(fig, panel, frame)
    footer_size = 9.5
    font = FT2Font(str(DATA / "Roboto-Regular.ttf"))
    descent_mm = -font.descender / font.units_per_EM * footer_size * 25.4 / 72
    fig.text(0.5, (5 + descent_mm) / PAGE_MM, FOOTER, color=ACCENT,
             size=footer_size, ha="center", va="baseline")
    return fig


def main():
    frame, coverage = bounds()
    OUTPUTS.mkdir(exist_ok=True)
    graph_path = load_graph(coverage)
    figure = compose(frame, analyse(graph_path, frame, coverage))
    for extension in ("png", "pdf"):
        path = OUTPUTS / f"{STEM}.{extension}"
        figure.savefig(path, dpi=DPI, metadata={"Title": TITLE, "Author": AUTHOR})
        print(f"Saved {path}")
    plt.close(figure)


if __name__ == "__main__":
    main()
