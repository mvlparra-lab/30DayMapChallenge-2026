"""Render the Day 22 world projections and export the animation."""

import hashlib
from pathlib import Path
from tempfile import NamedTemporaryFile, gettempdir

import imageio_ffmpeg
import numpy as np
import pyogrio
import pyproj
import shapely
from PIL import Image, ImageColor, ImageDraw, ImageFont
from pyproj.enums import TransformDirection


ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
OUTPUT = ROOT / "outputs"
COUNTRIES = DATA / "ne_110m_admin_0_countries.zip"
STEM = "day22-one-world-five-perspectives"
TITLE = "One World, Five Perspectives"
# The 300 mm layout width gives 4 pixels per millimeter and 40 px side margins.
SIZE = (1200, 1356)
MAP_BOX = (40, 96, 1160, 1218)
DESCRIPTION_Y = MAP_BOX[3] + 67
FOOTER_GAP_PX = 20  # 5 mm at 4 pixels per millimeter.
SUPERSAMPLE = 2
FPS = 10
HOLD_FRAMES = 24
FADE_FRAMES = 6
PAPER, INK, ACCENT = "#f8f3e8", "#3b322b", "#765239"
OCEAN, LAND, BORDER = (38, 83, 104), (225, 206, 170), (156, 132, 100)
WEB_LIMIT = np.degrees(np.arctan(np.sinh(np.pi)))

VIEWS = (
    ("Web Mercator (EPSG:3857)", "High latitudes appear much larger.",
     "EPSG:3857", WEB_LIMIT),
    ("Equal Earth", "Preserves relative area within a rounded world outline.",
     "+proj=eqearth +datum=WGS84 +type=crs", 90),
    ("Mollweide", "Preserves relative area within an elliptical outline.",
     "+proj=moll +R=6371007.1809 +type=crs", 90),
    ("Interrupted Goode Homolosine", "Preserves relative area, with cuts that reduce land distortion.",
     "+proj=igh +R=6371007.1809 +type=crs", 90),
    ("Spilhaus", "Centers the world ocean and preserves local angles away from the corners.",
     "ESRI:54099", 90),
)


def projection_grid(transformer, latitude_limit):
    """Fit the complete projection footprint using one scale for both axes."""
    longitude, latitude = np.meshgrid(
        np.linspace(-180, 180, 1441), np.linspace(-latitude_limit, latitude_limit, 721)
    )
    x, y = transformer.transform(longitude, latitude, errcheck=True)
    xmin, xmax = x.min(), x.max()
    ymin, ymax = y.min(), y.max()
    width = (MAP_BOX[2] - MAP_BOX[0]) * SUPERSAMPLE
    height = (MAP_BOX[3] - MAP_BOX[1]) * SUPERSAMPLE
    # Leave clearance around the sampled extent, including the Spilhaus corners.
    units = 1.012 * max((xmax - xmin) / width, (ymax - ymin) / height)
    columns = (np.arange(width) + 0.5 - width / 2) * units + (xmin + xmax) / 2
    rows = (height / 2 - np.arange(height) - 0.5) * units + (ymin + ymax) / 2
    return np.meshgrid(columns, rows), units


def polygon_parts(geometry):
    if geometry.geom_type == "Polygon":
        yield geometry
    elif hasattr(geometry, "geoms"):
        for part in geometry.geoms:
            yield from polygon_parts(part)


def prepare_countries():
    """Repair source polygons and split multipolygons for spatial filtering."""
    countries = pyogrio.read_dataframe(COUNTRIES, columns=[]).to_crs(4326)
    return [
        (index, part)
        for index, geometry in enumerate(countries.geometry, start=1)
        for part in polygon_parts(shapely.make_valid(geometry))
    ]


def recover_spilhaus_corners(transformer, x, y, lon, lat, units, countries):
    """Continue the inverse toward corners where PROJ's direct solver fails."""
    inverse = TransformDirection.INVERSE
    # Estimate the half-side along the midpoint of the eastern edge, where
    # the inverse is stable. Verify the round trip to detect wrapped results.
    lower, upper = 0.0, float(x.max())
    for _ in range(35):
        midpoint = (lower + upper) / 2
        east, north = transformer.transform(midpoint, 0, direction=inverse)
        px, py = transformer.transform(east, north)
        if np.hypot(px - midpoint, py) < 1:
            lower = midpoint
        else:
            upper = midpoint

    missing = (np.maximum(np.abs(x), np.abs(y)) < lower) & ~np.isfinite(lon)
    target_x, target_y = x[missing], y[missing]
    start = 0.90
    east, north = transformer.transform(start * target_x, start * target_y, direction=inverse)
    delta = 1e-7
    # Use each interior solution to seed the next one. All residuals and
    # derivatives come from the same registered Spilhaus forward transform.
    for fraction in np.linspace(start, 1, 21)[1:]:
        for _ in range(10):
            px, py = transformer.transform(east, north)
            ex, ey = transformer.transform(east + delta, north)
            nx, ny = transformer.transform(east, north + delta)
            a, b, c, d = ex - px, nx - px, ey - py, ny - py
            rx, ry = fraction * target_x - px, fraction * target_y - py
            det = a * d - b * c
            with np.errstate(divide="ignore", invalid="ignore"):
                de = delta * (d * rx - b * ry) / det
                dn = delta * (a * ry - c * rx) / det
            residual = np.hypot(rx, ry)
            pending = np.flatnonzero((residual > 1) & np.isfinite(de) & np.isfinite(dn))
            for damping in (1, 0.5, 0.25, 0.125, 0.0625):
                if pending.size == 0:
                    break
                trial_east = east[pending] + damping * de[pending]
                trial_north = north[pending] + damping * dn[pending]
                tx, ty = transformer.transform(trial_east, trial_north)
                improved = np.hypot(tx - fraction * target_x[pending],
                                    ty - fraction * target_y[pending]) < residual[pending]
                east[pending[improved]] = trial_east[improved]
                north[pending[improved]] = trial_north[improved]
                pending = pending[~improved]
    px, py = transformer.transform(east, north)
    error = np.hypot(px - target_x, py - target_y)
    failed = ~np.isfinite(error) | (error >= units / 16)
    # At the two singular corners, forward precision can be too low for
    # subpixel convergence. Accept a flat fill only if the estimates cluster
    # tightly and their geographic neighborhood is entirely in one polygon.
    for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        corner = failed & (sx * target_x > 0) & (sy * target_y > 0)
        if not corner.any():
            continue
        a, b = east[corner], north[corner]
        extent = shapely.box(a.min() - 0.01, b.min() - 0.01, a.max() + 0.01, b.max() + 0.01)
        if (not np.all(np.isfinite(a) & np.isfinite(b)) or np.ptp(a) > 0.001
                or np.ptp(b) > 0.001
                or not any(polygon.contains(extent) for _, polygon in countries)):
            raise ValueError("Could not classify the singular Spilhaus corner samples.")
    lon[missing], lat[missing] = east, north
    return np.flatnonzero(missing)[failed]


def render_projection(definition, latitude_limit, countries):
    """Rasterize projected polygons by querying their geographic preimages."""
    transformer = pyproj.Transformer.from_crs(4326, definition, always_xy=True)
    (x, y), units = projection_grid(transformer, latitude_limit)
    lon, lat = transformer.transform(x, y, direction=TransformDirection.INVERSE)
    corner_indices = np.empty(0, dtype=np.intp)
    if definition == "ESRI:54099":
        corner_indices = recover_spilhaus_corners(transformer, x, y, lon, lat, units, countries)
    valid = np.isfinite(lon) & np.isfinite(lat) & (np.abs(lat) <= latitude_limit)
    # Some inverse operations return coordinates outside the footprint.
    # The forward round trip rejects those samples and preserves empty lobes.
    indices = np.flatnonzero(valid)
    px, py = transformer.transform(lon.flat[indices], lat.flat[indices])
    indices = indices[np.hypot(px - x.flat[indices], py - y.flat[indices]) < units / 16]
    indices = np.union1d(indices, corner_indices)
    lon = lon.flat[indices]
    lat = lat.flat[indices]
    labels = np.zeros(len(indices), dtype=np.uint16)
    for country_id, polygon in countries:
        west, south, east, north = polygon.bounds
        nearby = np.flatnonzero(
            (lon >= west) & (lon <= east) & (lat >= south) & (lat <= north)
        )
        inside = shapely.contains_xy(polygon, lon[nearby], lat[nearby])
        labels[nearby[inside]] = country_id

    # Zero is outside the footprint, one is water, and higher values are countries.
    grid = np.zeros(x.shape, dtype=np.uint16)
    grid.flat[indices] = labels + 1
    if any(edge.any() for edge in (grid[0], grid[-1], grid[:, 0], grid[:, -1])):
        raise ValueError(f"The projection exceeds the map box: {definition}")
    rgb = np.empty((*grid.shape, 3), dtype=np.uint8)
    rgb[:] = ImageColor.getrgb(PAPER)
    rgb[grid == 1] = OCEAN
    rgb[grid > 1] = LAND
    # Stroke touching country IDs without drawing segments across cut lines.
    for ids, pixels in ((grid, rgb), (grid.T, rgb.transpose(1, 0, 2))):
        border = (ids[:-1] > 1) & (ids[1:] > 1) & (ids[:-1] != ids[1:])
        pixels[:-1][border] = BORDER
    return Image.fromarray(rgb).resize(
        (MAP_BOX[2] - MAP_BOX[0], MAP_BOX[3] - MAP_BOX[1]), Image.Resampling.LANCZOS
    )


def prepare_maps():
    """Cache only the five map panels outside the repository."""
    digest = hashlib.sha256()
    for source in (Path(__file__), COUNTRIES):
        digest.update(source.read_bytes())
    digest.update(f"{pyproj.proj_version_str}/{shapely.__version__}".encode())
    cache = Path(gettempdir()) / f"day22-projections-{digest.hexdigest()[:20]}.npz"
    if cache.is_file():
        with np.load(cache) as panels:
            return [Image.fromarray(panels[str(i)]) for i in range(len(VIEWS))]

    countries = prepare_countries()
    maps = []
    for name, _, definition, latitude_limit in VIEWS:
        print(f"Preparing {name}", flush=True)
        maps.append(render_projection(definition, latitude_limit, countries))
    with NamedTemporaryFile(dir=cache.parent, suffix=".npz", delete=False) as temporary:
        np.savez_compressed(temporary, **{str(i): np.asarray(panel) for i, panel in enumerate(maps)})
    Path(temporary.name).replace(cache)
    return maps


def base_page():
    page = Image.new("RGB", SIZE, PAPER)
    draw = ImageDraw.Draw(page)
    draw.text((600, 51), f"Day 22 - {TITLE}", fill=INK, anchor="mm",
              font=ImageFont.truetype(DATA / "Roboto-Bold.ttf", 51))
    footer = (f"#30DayMapChallenge | 2026 | Day - 22 | Projections | {TITLE} | "
              "Map by María Victoria León Parra")
    footer_font = ImageFont.truetype(DATA / "Roboto-Regular.ttf", 19)
    description_font = ImageFont.truetype(DATA / "Roboto-Regular.ttf", 22)
    description_bottom = DESCRIPTION_Y + max(
        description_font.getbbox(description, anchor="mm")[3] for _, description, _, _ in VIEWS
    )
    footer_y = description_bottom + FOOTER_GAP_PX - footer_font.getbbox(footer, anchor="mm")[1]
    draw.text((600, footer_y), footer, fill=ACCENT, anchor="mm", font=footer_font)
    return page


def compose(page, panel, view):
    frame = page.copy()
    frame.paste(panel, MAP_BOX[:2])
    name, description, _, _ = view
    draw = ImageDraw.Draw(frame)
    draw.text((600, MAP_BOX[3] + 25), name, fill=INK, anchor="mm",
              font=ImageFont.truetype(DATA / "Roboto-Bold.ttf", 32))
    draw.text((600, DESCRIPTION_Y), description, fill=INK, anchor="mm",
              font=ImageFont.truetype(DATA / "Roboto-Regular.ttf", 22))
    return frame


def timeline(page, views):
    """Yield unique frames and their durations in units of one video frame."""
    for index, current in enumerate(views):
        yield current, HOLD_FRAMES
        following = views[(index + 1) % len(views)]
        for step in range(1, 2 * FADE_FRAMES + 1):
            progress = (step - 0.5) / FADE_FRAMES
            weight = abs(1 - progress)
            eased = weight * weight * (3 - 2 * weight)
            view = current if step <= FADE_FRAMES else following
            yield Image.blend(page, view, eased), 1


def export_animation(page, views):
    # A shared palette avoids color shifts between scenes and preserves flat fills.
    sample_size = (360, round(360 * SIZE[1] / SIZE[0]))
    samples = Image.new("RGB", (sample_size[0], sample_size[1] * len(views) * 3))
    for index, view in enumerate(views):
        for step, opacity in enumerate((0.22, 0.66, 1.0)):
            sample = Image.blend(page, view, opacity).resize(sample_size, Image.Resampling.BOX)
            samples.paste(sample, (0, (3 * index + step) * sample_size[1]))
    palette = samples.quantize(colors=255)
    gif_frames, durations = [], []
    writer = imageio_ffmpeg.write_frames(
        str(OUTPUT / f"{STEM}.mp4"), SIZE, fps=FPS, codec="libx264", quality=None,
        macro_block_size=1, output_params=["-crf", "18", "-movflags", "+faststart"],
    )
    writer.send(None)
    try:
        for frame, count in timeline(page, views):
            gif_frames.append(frame.quantize(palette=palette, dither=Image.Dither.NONE))
            durations.append(count * 1000 // FPS)
            pixels = frame.tobytes()
            for _ in range(count):
                writer.send(pixels)
    finally:
        writer.close()
    gif_frames[0].save(
        OUTPUT / f"{STEM}.gif", save_all=True, append_images=gif_frames[1:],
        duration=durations, loop=0, disposal=1, optimize=True,
    )


def main():
    if tuple(map(int, pyproj.proj_version_str.split(".")[:2])) < (9, 6):
        raise RuntimeError("Spilhaus requires PROJ 9.6 or newer.")
    OUTPUT.mkdir(exist_ok=True)
    page = base_page()
    views = [compose(page, panel, view) for panel, view in zip(prepare_maps(), VIEWS, strict=True)]
    views[-1].save(OUTPUT / f"{STEM}.png", optimize=True, dpi=(101.6, 101.6))
    export_animation(page, views)


if __name__ == "__main__":
    main()
