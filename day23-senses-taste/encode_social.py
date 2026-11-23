"""Encode the settled Chrome captures as a looping GIF with timed holds."""

from pathlib import Path
import sys

from PIL import Image


def main(folder, durations):
    with Image.open(folder / "cover.png") as cover:
        if cover.size != (2400, 2400):
            raise ValueError(f"Unexpected cover size: {cover.size}")

    frames = []
    for index in range(len(durations)):
        with Image.open(folder / f"scene-{index}.png") as source:
            if source.size != (1200, 1000):
                raise ValueError(f"Unexpected GIF frame size: {source.size}")
            frames.append(source.convert("RGB"))

    # One palette sampled from every scene keeps map colours consistent.
    samples = Image.new("RGB", (600, 500 * len(frames)))
    for index, frame in enumerate(frames):
        samples.paste(frame.resize((600, 500), Image.Resampling.BOX), (0, 500 * index))
    palette = samples.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    output = folder / "preview.gif"
    indexed[0].save(output, save_all=True, append_images=indexed[1:],
                    duration=durations, loop=0, optimize=True, disposal=1)
    if output.stat().st_size >= 10_000_000:
        raise ValueError("GIF exceeds 10 MB.")


if __name__ == "__main__":
    main(Path(sys.argv[1]), [int(duration) for duration in sys.argv[2:]])
