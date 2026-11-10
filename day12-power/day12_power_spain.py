#!/usr/bin/env python3

"""
Based on: Ujaval Gandhi (Spatial Thoughts) - Creating Animated Flight Lines in QGIS
https://spatialthoughts.com/2019/03/21/animated-flight-lines/
Author: María Victoria León Parra
Project: 30DayMapChallenge 2026

Day 12 - Power | Spain’s High-Voltage Grid
OpenStreetMap transmission lines -> map by voltage -> optional animated pulses

Input: data/spain_high_voltage.geojson and data/country_context.geojson.
Run: python day12_power_spain.py
Dependencies: python -m pip install matplotlib numpy pillow
Output: map preview. Use --animate to preview the animation; use --export-png
        or --export-gif only when ready to save. No files are exported by default.
"""

import argparse
from pathlib import Path
import json

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation, PillowWriter
from matplotlib.collections import LineCollection, PolyCollection
from matplotlib.colors import to_rgb
from matplotlib import font_manager
from matplotlib.lines import Line2D

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
OUTPUT_DIR = BASE_DIR / "output"
TITLE = "Day 12 | Spain’s High-Voltage Grid"
FOOTER = "#30DayMapChallenge | 2026 | Day - 12 | Spain’s High-Voltage Grid | Map by María Victoria León Parra"

PAGE, PAGE_INK = "#dceef8", "#112d45"
SEA, LAND, BORDER = "#091625", "#162b40", "#344e66"
INK = "#e5f4ff"
VOLTAGE_COLORS = {220: "#FF6A00", 400: "#39FF14"}
FPS, DURATION = 18, 8


def read_features(path):
    if not path.exists():
        raise FileNotFoundError(f"Missing {path}. Keep the data folder next to this script.")
    return json.loads(path.read_text(encoding="utf-8"))["features"]



def project(coordinates):
    # Web Mercator, for a north-up view with a scale bar adjusted to local latitude.
    lon, lat = np.radians(np.asarray(coordinates, dtype=float)).T
    radius = 6_378_137
    return np.column_stack((radius * lon, radius * np.arcsinh(np.tan(lat))))



def prepare_layers(grid, countries):
    """Project the local GeoJSON layers into Web Mercator."""
    land_paths = [
        project(polygon[0])
        for feature in countries
        for polygon in feature["geometry"]["coordinates"]
    ]
    grid_paths = {
        kv: [(feature["properties"]["osm_id"], project(feature["geometry"]["coordinates"]))
             for feature in grid if feature["properties"]["voltage_kv"] == kv]
        for kv in VOLTAGE_COLORS
    }
    if not land_paths or not all(grid_paths.values()):
        raise ValueError("The boundary layer and both voltage classes must contain features.")
    return land_paths, grid_paths


def draw_frame(ax, bounds, scale_km, scale_lat, land_paths, grid_paths, *, inset=False):
    ax.set_facecolor(SEA)
    ax.add_collection(PolyCollection(land_paths, facecolors=LAND, edgecolors=BORDER,
                                     linewidths=0.55, zorder=1))
    for kv, width, opacity, zorder in [(220, 0.58, 0.78, 2), (400, 0.90, 0.98, 4)]:
        paths = [xy for _, xy in grid_paths[kv]]
        ax.add_collection(LineCollection(paths, colors=VOLTAGE_COLORS[kv],
                                         linewidths=width + 1.2, alpha=0.11,
                                         capstyle="round", zorder=zorder))
        ax.add_collection(LineCollection(paths, colors=VOLTAGE_COLORS[kv],
                                         linewidths=width, alpha=opacity,
                                         capstyle="round", zorder=zorder + 1))
    (xmin, ymin), (xmax, ymax) = project([bounds[:2], bounds[2:]])
    ax.set(xlim=(xmin, xmax), ylim=(ymin, ymax), aspect="equal", xticks=[], yticks=[])
    for spine in ax.spines.values():
        spine.set_color(BORDER)

    # North and scale on each frame. Scale is true at the stated reference latitude.
    north_x = 0.80 if inset else 0.956
    north_top, north_label = (0.90, 0.67) if inset else (0.899, 0.79)
    ax.annotate("N", xy=(north_x, north_top), xytext=(north_x, north_label),
                xycoords="axes fraction", ha="center", color=INK,
                fontsize=8 if inset else 12, fontweight="bold",
                arrowprops=dict(arrowstyle="-|>", color=INK,
                                lw=0.9 if inset else 2.0,
                                mutation_scale=9 if inset else 17), zorder=8)
    length = scale_km * 1_000 / np.cos(np.radians(scale_lat))
    fraction = length / (xmax - xmin)
    y = 0.08 if inset else 0.033
    x0 = 0.95 - fraction if inset else 0.045
    x1 = x0 + fraction
    ax.plot([x0, x1], [y, y], transform=ax.transAxes, color=INK, lw=1, zorder=8)
    for x in (x0, x1):
        ax.plot([x, x], [y - .012, y + .012], transform=ax.transAxes, color=INK, lw=1, zorder=8)
    ax.text((x0 + x1) / 2, y + (0.055 if inset else 0.025), f"{scale_km} km", transform=ax.transAxes,
            ha="center", color=INK, fontsize=7, zorder=8)


def create_map(land_paths, grid_paths):
    # 300 × 300 mm square; the same composition is used for both outputs.
    fig = plt.figure(figsize=(300 / 25.4, 300 / 25.4), facecolor=PAGE)
    fig.text(0.5, 0.946, TITLE, ha="center", va="center", color=PAGE_INK,
             fontsize=28, fontweight="bold")

    main = fig.add_axes([0.022, 0.108, 0.956, 0.788])
    draw_frame(main, (-9.83, 35.32, 4.53, 44.08), 100, 36, land_paths, grid_paths)
    islands = main.inset_axes([0.704, 0.0, 0.296, 0.2], zorder=9)
    draw_frame(islands, (-18.55, 27.44, -13.10, 29.72), 50, 28,
               land_paths, grid_paths, inset=True)
    islands.set_anchor("SE")
    for spine in islands.spines.values():
        spine.set_color("#64829b")
        spine.set_linewidth(0.85)

    main.legend(handles=[Line2D([0], [0], color=VOLTAGE_COLORS[kv], lw=2.2, label=f"{kv} kV")
                         for kv in (400, 220)],
                loc="lower right", bbox_to_anchor=(0.985, 0.205), frameon=False,
                labelcolor=INK, fontsize=11)
    fig.text(0.5, 0.057, FOOTER, ha="center", va="center", color=PAGE_INK, fontsize=10)
    return fig, main, islands


def build_pulse_tracks(grid_paths, ax, frame_count):
    """Sample a looping pulse along every visible line segment in this frame."""
    xmin, xmax = ax.get_xlim()
    ymin, ymax = ax.get_ylim()
    time = np.arange(frame_count) / frame_count
    positions, sizes, colors, phases = [], [], [], []

    for kv, paths in grid_paths.items():
        for osm_id, xy in paths:
            if (xy[:, 0].max() < xmin or xy[:, 0].min() > xmax
                    or xy[:, 1].max() < ymin or xy[:, 1].min() > ymax):
                continue
            distance = np.r_[0, np.cumsum(np.linalg.norm(np.diff(xy, axis=0), axis=1))]
            length = distance[-1]
            if length <= 0:
                continue

            # Stagger neighboring pulses and use whole cycles for a seamless GIF.
            offset = (int(osm_id) * 0.618033988749895) % 1
            cycles = 3 * (3 + int(osm_id) % 3)
            phase = (cycles * time + offset) % 1
            along = length * (1 - np.abs(2 * phase - 1))
            positions.append(np.column_stack([
                np.interp(along, distance, xy[:, dim]) for dim in (0, 1)
            ]))
            sizes.append(0.5 + 5 * np.clip(np.sqrt(length / 35_000), 0, 1))
            colors.append(to_rgb(VOLTAGE_COLORS[kv]))
            phases.append(phase)

    return (np.stack(positions, axis=1), np.asarray(sizes),
            np.asarray(colors), np.stack(phases, axis=1))


def create_animation(fig, main, islands, grid_paths):
    """Animate both map frames; pulses are illustrative, not measured flow."""
    frame_count = FPS * DURATION
    layers = []
    for ax in (main, islands):
        positions, sizes, colors, phases = build_pulse_tracks(grid_paths, ax, frame_count)
        x, y = positions[0].T
        halo = ax.scatter(x, y, s=sizes * 6, c=colors, linewidths=0, zorder=6)
        core_colors = 0.46 * colors + 0.54
        core = ax.scatter(x, y, s=sizes, c=core_colors, linewidths=0, zorder=7)
        layers.append((positions, colors, core_colors, phases, halo, core))

    def update(frame):
        artists = []
        for positions, colors, core_colors, phases, halo, core in layers:
            glow = 0.5 + 0.5 * np.cos(2 * np.pi * phases[frame])
            halo.set_offsets(positions[frame])
            core.set_offsets(positions[frame])
            halo.set_facecolor(np.column_stack([colors, 0.08 + 0.24 * glow]))
            core.set_facecolor(np.column_stack([core_colors, 0.42 + 0.50 * glow]))
            artists.extend((halo, core))
        return artists

    update(0)
    return FuncAnimation(fig, update, frames=frame_count,
                         interval=1000 / FPS, blit=False)


def main():
    parser = argparse.ArgumentParser(description="Preview Spain’s high-voltage grid.")
    parser.add_argument("--animate", action="store_true", help="Preview the animated map.")
    parser.add_argument("--export-png", action="store_true", help="Save a PNG to the output folder.")
    parser.add_argument("--export-gif", action="store_true", help="Save an animated GIF to the output folder.")
    args = parser.parse_args()

    try:
        grid = read_features(DATA_DIR / "spain_high_voltage.geojson")
        countries = read_features(DATA_DIR / "country_context.geojson")
        land_paths, grid_paths = prepare_layers(grid, countries)
        for kv, paths in grid_paths.items():
            print(f"{kv} kV: {len(paths):,} line segments")

        fonts = {font.name for font in font_manager.fontManager.ttflist}
        plt.rcParams["font.family"] = "Roboto" if "Roboto" in fonts else "DejaVu Sans"
        fig, ax, islands = create_map(land_paths, grid_paths)
        if args.export_png or args.export_gif:
            OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        if args.export_png:
            target = OUTPUT_DIR / "day12_spain_high_voltage.png"
            fig.savefig(target, dpi=300)
            print(f"Saved: {target}")
        if args.animate or args.export_gif:
            animation = create_animation(fig, ax, islands, grid_paths)
            if args.export_gif:
                target = OUTPUT_DIR / "day12_spain_high_voltage.gif"
                animation.save(target, writer=PillowWriter(fps=FPS), dpi=75)
                print(f"Saved: {target}")
        plt.show()
    except (OSError, RuntimeError, ValueError) as error:
        parser.exit(1, f"Error: {error}\n")


if __name__ == "__main__":
    main()
