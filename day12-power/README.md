# Day 12 - Power | Spain’s High-Voltage Grid

For the Power theme, I mapped Spain’s 220 kV and 400 kV overhead transmission lines. Pulses of light move along the lines in an eight-second loop, including in the Canary Islands inset.

## Tools

- Python and NumPy to calculate pulse positions along the lines
- Matplotlib to compose the map and animate the pulses
- Pillow to export the GIF

## Workflow

1. Load the transmission lines and country outlines from local GeoJSON files.
2. Project the data to Web Mercator and style the lines by voltage: orange for 220 kV and green for 400 kV.
3. Compose the main map and the Canary Islands inset, each with its own north arrow and scale bar.
4. Animate pulses along the mapped lines and export the result as a looping GIF.

Run these commands from `day12-power/`:

```sh
python -m pip install matplotlib numpy pillow
python day12_power_spain.py --export-png --export-gif
```

The exports are saved in `output/`. Run the script without flags to preview the static map, or use `--animate` to preview the animation.

## Local data

Keep `data/` next to [`day12_power_spain.py`](./day12_power_spain.py). It contains `spain_high_voltage.geojson` and `country_context.geojson`. No data download is needed to run the script.

## Sources and inspiration

- **Transmission lines:** © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), ODbL. [Source extract](https://github.com/ningunaparte/spain-power-plants), May 2026.
- **Country outlines:** [Natural Earth, 1:10m Admin 0 Countries](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-0-countries/).
- **Tutorial:** Ujaval Gandhi, [Creating Animated Flight Lines in QGIS](https://spatialthoughts.com/2019/03/21/animated-flight-lines/). I adapted the moving points from flight paths in QGIS to power lines in Python.

## Notes

- The map shows the overhead lines available in the source extract. Lines missing from the extract are not shown.
- The pulses illustrate the network. They do not represent measured electricity flow or its direction.
- The layout was the hardest part for me in Python. Getting the legend, scale bars and Canary Islands inset where I wanted them took more trial and error than the animation.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/portfolio) · [Back to challenge](../)
