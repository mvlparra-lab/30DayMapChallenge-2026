# Day 08 - Utopia | Is Augsburg a 15-minute city?

Augsburg ranked second for life satisfaction among 40 major German cities in the 2026 SKL Glücksatlas. For the Utopia theme, I wanted to look at one aspect of everyday life in the city where I live: how easy is it to reach essential services on foot?

## Tools

- R and `r5r` for the walking accessibility analysis
- QGIS for the final map

## Workflow

1. Create a 100 m grid for residential areas within Augsburg.
2. Identify supermarkets, public park entrances, schools, pharmacies and public transport stops.
3. Estimate walking times from each grid cell to the nearest destination in each category using the street network.
4. Map whether each cell has access to all five services within a 15-minute walk.

## Local data

The analysis uses an Augsburg municipal boundary, a residential grid, and walking network and destination data from OpenStreetMap.

The R scripts and instructions are in the [technical README](./augsburg_walkability/README.md).

## Sources and inspiration

- [Nat Henry’s 15-minute city tutorial](https://henryspatialanalysis.com/news/tutorial-15-minute-city-interactive-map.html)
- [OpenStreetMap](https://www.openstreetmap.org/copyright)
- [SKL Glücksatlas 2026: Augsburg](https://www.skl-gluecksatlas.de/artikel/staedteranking-2026/augsburg.html)

## Notes

- All five services were within a 15-minute walk of 56.2% of the residential grid cells analysed. Each cell carries equal weight in this calculation.
- The analysis includes nearby destinations outside the municipal boundary to account for services accessible from the edges of the city.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/portfolio) · [Back to challenge](../)
