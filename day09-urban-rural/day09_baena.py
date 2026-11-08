#!/usr/bin/env python3

"""
Based on: Spatial Workflow - How to Calculate Coverage and Floor Area Ratio in Python
https://www.spatialworkflow.io/building-coverage-far-python/
Author: María Victoria León Parra
Project: 30DayMapChallenge 2026

Day 09 - Urban-rural | Baena, Town & Countryside
Cadastre building footprints -> building coverage in 100 m cells -> QGIS layer

Input: baena_catastro.gpkg, containing the INSPIRE BU Building footprints for Baena.
       Prepare it from https://www.catastro.hacienda.gob.es/webinspire/
Run: python day09_baena.py
Dependencies: python -m pip install "geopandas>=1" pyogrio
Output: baena_coverage_catastro.gpkg, layer building_coverage_catastro_100m.

This script reproduces the inset analysis. The main map and print layout were
made in QGIS with the Cadastre footprints and SIGPAC 2026 land-use data.
"""

import argparse
from pathlib import Path

import geopandas as gpd
import pyogrio
from pyproj import Transformer
from shapely.geometry import box

CRS = "EPSG:25830"
CENTRE_LON_LAT = (-4.326, 37.615)
CELL_SIZE_M = 100
CELLS_PER_SIDE = 44
GRID_LAYER = "building_coverage_100m"
OUTPUT_LAYER = "building_coverage_catastro_100m"
SOURCE = "Dirección General del Catastro (INSPIRE BU)"
POLYGON_TYPES = ("Polygon", "MultiPolygon")


def make_grid():
    """Recreate the original 4.4 km study grid without downloading OSM data."""
    x, y = Transformer.from_crs("EPSG:4326", CRS, always_xy=True).transform(
        *CENTRE_LON_LAT
    )
    half_width = CELLS_PER_SIDE // 2 * CELL_SIZE_M
    west = round(x / CELL_SIZE_M) * CELL_SIZE_M - half_width
    south = round(y / CELL_SIZE_M) * CELL_SIZE_M - half_width
    cells = [
        box(x0, y0, x0 + CELL_SIZE_M, y0 + CELL_SIZE_M)
        for y0 in range(south, south + 2 * half_width, CELL_SIZE_M)
        for x0 in range(west, west + 2 * half_width, CELL_SIZE_M)
    ]
    return gpd.GeoDataFrame(
        {"cell_id": range(1, len(cells) + 1)}, geometry=cells, crs=CRS
    )


def read_grid(path):
    """Reuse only the geometry and cell ID of an existing grid."""
    if path is None:
        return make_grid()
    grid = gpd.read_file(path, layer=GRID_LAYER)[["cell_id", "geometry"]].to_crs(CRS)
    if (
        grid.empty
        or grid["cell_id"].isna().any()
        or not grid["cell_id"].is_unique
        or ((grid.area - CELL_SIZE_M**2).abs() > 0.1).any()
    ):
        raise ValueError("The input grid must contain valid 100 m cells with unique IDs.")
    return grid


def read_buildings(path, layer):
    """Load the prepared Cadastre Building layer, excluding BuildingPart."""
    if layer is None:
        candidates = []
        for name, geometry_type in pyogrio.list_layers(path):
            if not geometry_type or "polygon" not in geometry_type.lower():
                continue
            if "buildingpart" in name.lower().replace("_", "").replace(" ", ""):
                continue
            fields = pyogrio.read_info(path, layer=name)["fields"]
            if "built_pct" not in fields:
                candidates.append(name)
        if len(candidates) != 1:
            choices = ", ".join(candidates) or "none detected"
            raise ValueError(f"Specify the footprint layer with --layer NAME. Candidates: {choices}")
        layer = candidates[0]

    buildings = gpd.read_file(path, layer=layer).to_crs(CRS)[["geometry"]]
    buildings = buildings.loc[buildings.geometry.notna()].copy()
    buildings.geometry = buildings.geometry.make_valid()
    buildings = buildings.explode(index_parts=False, ignore_index=True)
    return buildings.loc[
        buildings.geom_type.isin(POLYGON_TYPES) & ~buildings.is_empty
    ].copy()


def calculate_coverage(grid, buildings):
    """Calculate the percentage of each cell occupied by building footprints."""
    # Intersect at cell boundaries, then dissolve to avoid double-counting overlaps.
    pieces = gpd.overlay(
        grid[["cell_id", "geometry"]],
        buildings,
        how="intersection",
        keep_geom_type=True,
    )
    if pieces.empty:
        raise ValueError("No Cadastre footprints intersect the study grid.")

    occupied = pieces.dissolve(by="cell_id").geometry.area
    result = grid.copy()
    area_m2 = result["cell_id"].map(occupied).fillna(0)
    result["built_m2"] = area_m2.round(2)
    result["built_pct"] = (100 * area_m2 / result.area).clip(0, 100).round(2)
    result["source"] = SOURCE
    return result


def main():
    parser = argparse.ArgumentParser(description="Calculate 100 m building coverage for Baena from Cadastre footprints.")
    parser.add_argument("--buildings", type=Path, default=Path("baena_catastro.gpkg"))
    parser.add_argument("--layer", help="Name of the Building footprint layer, if needed.")
    parser.add_argument(
        "--grid", type=Path, help=f"Optional GeoPackage containing {GRID_LAYER}."
    )
    parser.add_argument(
        "--output", type=Path, default=Path("baena_coverage_catastro.gpkg")
    )
    args = parser.parse_args()

    try:
        if not args.buildings.is_file():
            raise ValueError(f"Building input not found: {args.buildings}")
        if args.output.exists():
            raise ValueError(f"Output already exists: {args.output}. Choose another --output.")
        if args.output.suffix.lower() != ".gpkg":
            raise ValueError("Output must have a .gpkg extension.")
        grid = read_grid(args.grid)
        buildings = read_buildings(args.buildings, args.layer)
        coverage = calculate_coverage(grid, buildings)
        coverage.to_file(args.output, layer=OUTPUT_LAYER, driver="GPKG", index=False)
    except (OSError, RuntimeError, ValueError) as error:
        parser.exit(1, f"Error: {error}\n")

    print(f"Saved: {args.output.resolve()}")
    print(f"{len(coverage):,} cells | {(coverage['built_m2'] > 0).sum():,} with buildings")


if __name__ == "__main__":
    main()
