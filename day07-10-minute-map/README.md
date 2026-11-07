# Day 07 - 10 Minute Map | A World of Forests 🌳

How much of each country’s land area is covered by forests? This map shows the percentage for 2024, with darker greens indicating a higher share of forest area.

## Tools

Python, pandas, GeoPandas, Matplotlib and pyproj.

## Workflow

1. Read the 2024 forest area figures from the World Bank CSV.
2. Download the Natural Earth country boundaries.
3. Join the forest area figures to the boundaries using country codes.
4. Draw the map in the Robinson projection with a green colour scale, north arrow and scale bar.
5. Export the map as a PNG at 300 dpi.

## Local data

Keep `API_AG.LND.FRST.ZS_DS2_en_csv_v2_811.csv` in the same folder as [`day07_10_minute_map.ipynb`](./day07_10_minute_map.ipynb).

Run the notebook cells in order. An internet connection is needed to download the Natural Earth boundaries as `countries.zip`.

## Sources and inspiration

- **Forest area:** [FAO via the World Bank, Forest area (% of land area)](https://data.worldbank.org/indicator/AG.LND.FRST.ZS).
- **Country boundaries:** [Natural Earth, Admin 0 Countries](https://www.naturalearthdata.com/downloads/110m-cultural-vectors/110m-admin-0-countries/).
- **Tutorial:** [Mapping Global Coffee in 10 Minutes](https://www.youtube.com/watch?v=a3CB5x3XQmg) by Milan Janosov. I adapted his Python workflow to map forests instead of coffee.

## Notes

I studied the tutorial before starting the timer. The first version took **9 minutes and 28.63 seconds**. I refined the colours and layout afterwards.

The join matched 168 countries and territories. Grey indicates no data. The colours show national percentages, not the locations of individual forests. The scale bar is calibrated at the equator.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/) ·
[Back to the challenge](../README.md)
