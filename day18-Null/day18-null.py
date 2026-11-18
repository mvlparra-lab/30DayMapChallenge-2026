# # Day 18 | How Much Life Is on Mars?
#
# **Author:** María Victoria León Parra
# **Day:** 18, NULL, #30DayMapChallenge 2026
# **Purpose:** Map unknown organism density across the entire Martian surface.
# **Source:** NASA/MOLA global relief and the IAU/USGS Gazetteer.
# **Tutorial:** [Tutorial 5, section 0.1](https://www.generic-mapping-tools.org/agu24workshop/tut05_topography.html#d-map-view)
# **Workflow:** Render MOLA in Mollweide, add geographic context and a single
# global NULL legend, and export the print layout.
# **Run:** Create the environment from environment.yml and run `python day18-null.py`.

import argparse
import csv
import math
from pathlib import Path
from tempfile import TemporaryDirectory

import pygmt
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
OUTPUT = ROOT / "outputs" / "day18-null-mars.png"

DPI = 300
PAGE_WIDTH_MM = 300
PAGE_HEIGHT_MM = 225
MARGIN_MM = 10
MAP_TOP_MM = 36
MAP_WIDTH_MM = PAGE_WIDTH_MM - 2 * MARGIN_MM
MAP_HEIGHT_MM = MAP_WIDTH_MM / 2
MARS_EQUATORIAL_RADIUS_KM = 3396.19
SCALE_KM = 2000
CENTRAL_LONGITUDE = 180
REGION = [0, 360, -90, 90]

PAPER = "#211815"
INK = "#f7e7d7"
MUTED = "#dec4b0"
RULE = "#74584a"
LABEL = "#2b1b16"
HALO = "#f5dac1"

TITLE = "Day 18 | How Much Life Is on Mars?"
FOOTER = (
    "#30DayMapChallenge | 2026 | Day – 18 | NULL | "
    "How Much Life Is on Mars? | Map by María Victoria León Parra"
)


def px(mm):
    """Convert a physical layout measurement to output pixels."""
    return round(mm / 25.4 * DPI)


def font(points, bold=False):
    """Load bundled Roboto at the requested print size."""
    weight = "Bold" if bold else "Regular"
    return ImageFont.truetype(str(DATA / f"Roboto-{weight}.ttf"), round(points * DPI / 72))


def render_relief(resolution):
    """Render global MOLA as a transparent Mollweide basemap."""
    relief = pygmt.datasets.load_mars_relief(resolution=resolution)
    with TemporaryDirectory(prefix="day18-mars-") as temporary:
        palette = Path(temporary) / "mars.cpt"
        # Elevation controls the background tones only. Units are metres.
        palette.write_text(
            "-10000 171/118/91 -5000 192/135/108\n"
            "-5000 192/135/108 0 217/162/133\n"
            "0 217/162/133 5000 230/184/154\n"
            "5000 230/184/154 12000 239/202/173\n"
            "12000 239/202/173 23000 249/225/193\n",
            encoding="ascii",
        )
        layer = Path(temporary) / "relief.png"
        with pygmt.config(PROJ_ELLIPSOID=str(MARS_EQUATORIAL_RADIUS_KM * 1000)):
            figure = pygmt.Figure()
            figure.grdimage(
                grid=relief,
                region=REGION,
                projection=f"W{CENTRAL_LONGITUDE}/{MAP_WIDTH_MM / 10}c",
                cmap=str(palette),
                shading="+a315+nt0.38",
                dpi=DPI,
            )
            figure.savefig(str(layer), dpi=DPI, transparent=True)
        with Image.open(layer) as image:
            rgba = image.convert("RGBA")
            return rgba.crop(rgba.getbbox())


def map_position(longitude_east, latitude_north):
    """Project a planetocentric point into layout millimetres."""
    longitude = math.radians((longitude_east - CENTRAL_LONGITUDE + 180) % 360 - 180)
    latitude = math.radians(latitude_north)
    # Solve the spherical Mollweide auxiliary-angle equation by bisection.
    lower, upper = -math.pi / 2, math.pi / 2
    target = math.pi * math.sin(latitude)
    for _ in range(48):
        theta = (lower + upper) / 2
        if 2 * theta + math.sin(2 * theta) < target:
            lower = theta
        else:
            upper = theta
    theta = (lower + upper) / 2
    x = PAGE_WIDTH_MM / 2 + MAP_WIDTH_MM / 2 * longitude / math.pi * math.cos(theta)
    y = MAP_TOP_MM + MAP_HEIGHT_MM / 2 * (1 - math.sin(theta))
    return x, y


def draw_toponyms(draw):
    """Place official names at or near their catalogued centres."""
    label_font = font(10, bold=True)
    labels = []
    with (DATA / "mars-toponyms.csv").open(encoding="utf-8", newline="") as source:
        for row in csv.DictReader(source):
            x, y = map_position(float(row["longitude_east"]), float(row["latitude_north"]))
            label_x = x + float(row["label_dx_mm"])
            label_y = y + float(row["label_dy_mm"])
            label_at = (px(label_x), px(label_y))
            if (x, y) != (label_x, label_y):
                # Stop at the padded text box and outline the guide for contrast.
                left, top, right, bottom = draw.textbbox(
                    (0, 0), row["name"], anchor="mm", font=label_font,
                )
                dx, dy = px(x) - label_at[0], px(y) - label_at[1]
                gap = px(0.85)
                half_width = max(-left, right) + gap
                half_height = max(-top, bottom) + gap
                reach = max(abs(dx) / half_width, abs(dy) / half_height)
                if reach > 1:
                    end = (round(label_at[0] + dx / reach), round(label_at[1] + dy / reach))
                    guide = ((px(x), px(y)), end)
                    draw.line(guide, fill=HALO, width=px(0.65))
                    draw.line(guide, fill=LABEL, width=px(0.32))
            labels.append((label_at, row["name"]))

    for label_at, name in labels:
        draw.text(
            label_at, name, anchor="mm", font=label_font, fill=LABEL,
            stroke_width=px(0.22), stroke_fill=HALO,
        )


def draw_orientation(draw):
    """Draw north and a scale calibrated to the equatorial map width."""
    nx, ny = PAGE_WIDTH_MM - MARGIN_MM - 9, 44
    draw.text((px(nx), px(ny - 2)), "N", anchor="mb", font=font(10, True), fill=INK)
    draw.polygon(
        [(px(nx), px(ny)), (px(nx - 2.4), px(ny + 9)),
         (px(nx), px(ny + 7)), (px(nx + 2.4), px(ny + 9))],
        fill=INK,
    )

    # Mollweide is linear in longitude along the equator.
    length = MAP_WIDTH_MM * SCALE_KM / (2 * math.pi * MARS_EQUATORIAL_RADIUS_KM)
    x, y = PAGE_WIDTH_MM - MARGIN_MM - 7 - length, 163
    draw.text((px(x), px(y - 4)), "Scale at the equator", anchor="lb",
              font=font(9), fill=INK)
    draw.line((px(x), px(y), px(x + length), px(y)), fill=INK, width=px(0.24))
    for tick in (x, x + length):
        draw.line((px(tick), px(y - 1.3), px(tick), px(y + 1.3)), fill=INK, width=px(0.24))
    draw.text((px(x), px(y + 3)), "0", anchor="mt", font=font(8), fill=MUTED)
    draw.text((px(x + length), px(y + 3)), f"{SCALE_KM:,} km", anchor="mt",
              font=font(8), fill=MUTED)


def main():
    """Compose the global NULL map and save the 300 dpi PNG."""
    parser = argparse.ArgumentParser(description=__doc__ or main.__doc__)
    parser.add_argument(
        "--resolution", default="15m", choices=("01d", "30m", "15m", "10m"),
        help="Global MOLA grid spacing. Use 01d for the original tutorial resolution.",
    )
    args = parser.parse_args()
    relief = render_relief(args.resolution)
    size = (px(MAP_WIDTH_MM), px(MAP_HEIGHT_MM))
    page = Image.new("RGB", (px(PAGE_WIDTH_MM), px(PAGE_HEIGHT_MM)), PAPER)
    plate = relief.resize(size, Image.Resampling.LANCZOS)
    page.paste(plate, ((page.width - plate.width) // 2, px(MAP_TOP_MM)), plate)

    draw = ImageDraw.Draw(page)
    center = px(PAGE_WIDTH_MM / 2)
    draw.text((center, px(22)), TITLE, anchor="mm", font=font(31, True), fill=INK)
    draw_toponyms(draw)
    draw_orientation(draw)

    # The thematic status is one global statement. No density raster is needed.
    draw.text((center, px(187)), "NULL — Unknown density", anchor="mm",
              font=font(17, True), fill=INK)
    draw.text(
        (center, px(195)),
        "No data are available to estimate how many living organisms there are per km² on Mars.",
        anchor="mm", font=font(12), fill=INK,
    )
    draw.text((center, px(207)), "Relief: NASA/MOLA  ·  Place names: IAU/USGS",
              anchor="mm", font=font(9), fill=MUTED)
    draw.line((px(MARGIN_MM), px(212), px(PAGE_WIDTH_MM - MARGIN_MM), px(212)),
              fill=RULE, width=px(0.18))
    draw.text((center, px(219)), FOOTER, anchor="mb", font=font(9), fill=MUTED)

    OUTPUT.parent.mkdir(exist_ok=True)
    page.save(OUTPUT, dpi=(DPI, DPI), optimize=True)
    print(f"Saved {OUTPUT} ({page.width} × {page.height} px)")


if __name__ == "__main__":
    main()
