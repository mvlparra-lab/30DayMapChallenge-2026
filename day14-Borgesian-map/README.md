# Day 14 | Cartagena in 1799

A small square in Cartagena's historic centre in Juan José Ordovás’s 1799 plan, with the full plan and a photograph of the Cartagena model above it.

[View the map](linkedin.png) · [Download the print PDF](output/day14_borgesian_map_print.pdf)

## Tools

Python, Jupyter, Pillow, NumPy, Matplotlib, PyMuPDF and fontTools.

## Workflow

1. Load the original Ordovás plan and the photograph of the Cartagena model.
2. Measure the basin in source pixels and compare the two measurements with its documented dimensions.
3. Expand the selected historic-centre crop to a nominal 196 × 196 m to include more of the surrounding streets and blocks.
4. Crop the top of the model photograph to match the plan’s aspect ratio and align the two references.
5. Export the PNG and PDF from the same layout. Verify the PDF dimensions and embedded Roboto Black font.

## Local data

Install the dependencies, then open [day14_borgesian_map.ipynb](day14_borgesian_map.ipynb) from this day’s folder and use **Run All**.

```bash
python -m pip install -r requirements.txt
```

The original Ordovás scan, model photograph, Roboto Black font and font license are included in `data/` for offline use.

## Sources and inspiration

- **Plan** — Juan José Ordovás, *Plano de la plaza de Cartagena y su Arsenal* (1799), Cartoteca AT-161/27. The 1,972 × 1,218 JPEG is the original Commons file, a public-domain reproduction. [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Cartagena_Arsenal_1799.jpg)
- **Calibration** — The Spanish Navy documents the 550 × 318 m excavated basin. The engraved scale labels are indistinct in the Commons scan and the annotated municipal archive reproduction. [Spanish Navy Arsenal history](https://armada.defensa.gob.es/ArmadaPortal/page/Portal/ArmadaEspannola/conocenosorganizacion/prefLang-es/04Apoyofuerza--02jal--05Arsenales--03arsenalcartagena) · [Municipal archive, PDF page 14](https://archivo.cartagena.es/gestion/documentos/22601.pdf)
- **Model** — The Ayuntamiento de Cartagena documents the 1:700 model. The reference photograph is cropped from the top for the layout. The original is by P4K1T0, CC BY-SA 4.0. [Municipal documentation](https://www.cartagena.es/detalle_noticias.asp?id=37021) · [Photograph](https://commons.wikimedia.org/wiki/File:Cartagena_y_su_Arsenal_durante_el_siglo_XVIII_(20221102_122219).jpg) · [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
- **Layout and type** — [Matplotlib’s Figure size in different units](https://matplotlib.org/stable/gallery/subplots_axes_and_figures/figure_size_units.html) and [Google’s Roboto Black](https://github.com/googlefonts/roboto/blob/main/src/hinted/Roboto-Black.ttf), Apache 2.0.

## Notes

- The transverse basin span is 297 px across 318 m, from (573, 835) to (870, 835), giving 0.9340 px/m. The longitudinal check is 493 px across 550 m, from (690, 502) to (690, 995), giving 0.8964 px/m. The 4.0% difference shows the sensitivity to shoreline interpretation, historical drafting and scan distortion.
- The selected square is centred at (1630, 506) in source pixels. Its 196 m side spans about 183.06 source pixels on each side. The 1:700 ratio sets the nominal target paper scale. The crop has not been checked against physical measurements of the model. Source resolution limits fine detail.
- **Print at 100% / Actual size.** The [PDF](output/day14_borgesian_map_print.pdf) is **300 × 410 mm**, with a **280 × 280 mm** map panel and **10 mm** left and right margins. The PDF embeds Roboto Black at weight 900.
- The [PNG](linkedin.png) shares the PDF layout and aspect ratio at **3000 × 4100 pixels**. Its physical display size depends on the screen.

## Author

María Victoria León Parra

[Portfolio](https://vl-portfolio.lovable.app/portfolio)
