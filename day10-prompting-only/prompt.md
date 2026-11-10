Vamos a crear el **Day 10 - Prompting only | Augsburg, Where Water Runs** del `30DayMapChallenge-2026`.

**1. Revisa el formato del repositorio.** Lee el README general y los README y el código de `day02-lines/` y `day03-polygons/`. Usa el día 2 como referencia principal para el flujo de OpenStreetMap y compara ambos para identificar las convenciones del Challenge: estructura de carpetas, nombres de archivos, organización del código, rutas relativas y secciones del README. Sigue esas convenciones. Escribe el README y los comentarios del código en inglés.

**2. Prepara los datos.** Crea `day10-prompting-only/` y prepara con Python las capas para mostrar cómo el agua del Lech entra en la red de canales de Augsburgo en Hochablass y llega al casco histórico. Usa OpenStreetMap para las geometrías y las fichas municipales de [Hochablass](https://wassersystem-augsburg.de/de/objekte/hochablass-lechwehr) y [Lechkanäle](https://wassersystem-augsburg.de/de/objekte/lechkanaele) para comprobar el recorrido. Distingue el recorrido documentado de los canales de contexto. Deja el Vorderer Lech como contexto porque se alimenta desde otra toma.

**3. Guarda y verifica.** Ejecuta el código de preparación de datos y comprueba que las capas se pueden abrir. Crea el README del día con la misma estructura que los anteriores, documentando solo lo que ya esté hecho. Guarda también este prompt: estamos adaptando el [tutorial de Tyson Swetnam](https://tyson-swetnam.github.io/intro-gpt/tutorials/publichealth/gis/?utm_source=chatgpt.com) y quiero conservar el registro de las instrucciones.

Trabaja solo dentro de `day10-prompting-only/`. Todavía no dibujes el mapa, no actualices el README general ni subas nada a GitHub. Al terminar, dame la ruta completa de Windows, los archivos creados y qué convenciones has seguido.

## Step 2

Añade el mapa al notebook `day10_prompting_only_augsburg.ipynb`, en una sección después de la preparación de datos. Usa el notebook del día 2 como referencia para el orden de las celdas, las rutas relativas, los comentarios en inglés y la exportación.

Crea **Day 10 - Prompting only | Augsburg, Where Water Runs**. En una composición cuadrada, muestra el Lech, marca la toma de Hochablass y destaca en azul el recorrido documentado hasta los ramales Mittlerer Lech y Hinterer Lech. Deja la red secundaria, incluido el Vorderer Lech, en un tono más suave. Etiqueta solo lo necesario para seguir el agua. Incluye norte, escala gráfica, leyenda breve en inglés, crédito a OpenStreetMap y el pie habitual del Challenge.

Ejecuta el notebook de principio a fin y exporta el PNG como borrador. Actualiza el README con los pasos para regenerar los datos y el mapa, ya que `data/` está excluida de Git. Añade este prompt a `prompt.md` como **Step 2**

## Step 3

Refina el mapa existente en el mismo notebook. Añade el rótulo discreto **Augsburg Old Town** cerca de los ramales Mittlerer Lech y Hinterer Lech, sin tapar sus etiquetas. Coloca dos flechas pequeñas sobre el recorrido azul para indicar el sentido del agua desde Hochablass hacia el casco histórico, solo en tramos donde el sentido esté verificado.

Cambia **Documented route** por **Water route to the Old Town** en la leyenda.

Sustituye el pie inferior por esta línea exacta, manteniendo el estilo y la alineación actuales:

`#30DayMapChallenge | 2026 | Day - 10 | Prompting only | Augsburg, Where Water Runs | Map by María Victoria León Parra`

Conserva el encuadre, la paleta y el título. Exporta una nueva versión sin sobrescribir el borrador, guarda estas instrucciones en `prompt.md` como **Step 3** y dame la ruta del PNG.
