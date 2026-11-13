# Day 13 - Interactions | Cabo de Palos & La Manga

An interactive map for the #30DayMapChallenge 2026 comparing where restaurants, bars and pubs are mapped in Cabo de Palos and southern La Manga. Both maps start at the same scale, and a shared set of filters lets you compare the same categories side by side.

## Tools

- Python
- Jupyter Notebook
- OSMnx
- GeoPandas
- Folium

## Workflow

1. Define two study areas of the same size, one for Cabo de Palos and one for southern La Manga.
2. Retrieve points of interest from OpenStreetMap using OSMnx and prepare them as map markers, keeping their names and categories.
3. Build two Folium maps with shared category filters. Click a marker to see the venue details or drag the divider to give either map more space.
4. Export the interactive viewer as `index.html`.

To regenerate the viewer, install the dependencies:

```bash
python -m pip install jupyter osmnx geopandas folium
```

Open the notebook in this folder and run all cells in order.

## Local data

The notebook retrieves the venue data from OpenStreetMap. An internet connection is required for the initial download. The generated HTML and other outputs are kept outside this repository.

## Sources and inspiration

- Data: [OpenStreetMap contributors](https://www.openstreetmap.org/copyright)
- Inspiration: [Interactive POI Visualization in Python with OpenStreetMap Data](https://www.youtube.com/watch?v=SyOF6TWFnvA) by Milan Janosov

## Notes

The comparison covers the two selected study areas. OpenStreetMap coverage may vary between them, so the map shows recorded venues rather than a complete business directory.

## Author

María Victoria León Parra
