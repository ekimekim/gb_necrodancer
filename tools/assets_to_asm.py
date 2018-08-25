"""This tool converts the images under a directory (including subdirs) into an RGBDS asm include file.
It scans for *.json files that contain the keys:
	"image": The target image file, absolute or relative to this file.
	"palette": The palette (mapping from image pixel values to GB data values).
	            This should take the form of a 4-item list of pixel values, mapping
	            to GB data values 0-3 respectively. Pixel values depend on the mode of the image,
	            eg. a 3-item list [R, G, B] for color images, a simple integer for greyscale.
	"length": Optional. Number of tiles in the image. If not given, is worked out from image size.
	"name": Optional. The name of the include file to produce. Defaults to the json file's name (not including .json suffix).
	"tall_sprites": boolean, optional. See below.

Images are scanned for tiles left-to-right, then top-to-bottom. eg. in a 32x16 image, the tiles would be numbered:
	1234
	5678
However, to support 8x16 sprites being in the same order in the file as they are on screen,
if the tall_sprites option is set, it will read tiles in vertical pairs, like so:
	1357
	2468

For each json file / image file, it produces an asm file in the output directory that defines the data.
"""

import json
import os
import sys
import traceback

try:
	from PIL import Image
except ImportError:
	sys.stderr.write("This tool requires the Python Image Library or equivalent.\n"
	                 "The best way to install it is using pip: pip install pillow")
	raise


def main(targetdir, outdir):
	any_failed = False
	for path, dirs, files in os.walk(targetdir):
		for filename in files:
			if not filename.endswith('.json'):
				continue
			filepath = os.path.join(path, filename)
			try:
				process_file(targetdir, filepath, outdir)
			except Exception:
				sys.stderr.write("An error occurred while processing file {!r}:".format(filepath))
				traceback.print_exc()
				any_failed = True
	sys.exit(1 if any_failed else 0)


def process_file(targetdir, filepath, outdir):
	filepath_dir = os.path.dirname(filepath)

	with open(filepath) as f:
		meta = json.load(f)

	imagepath = meta['image']
	if not os.path.isabs(imagepath):
		imagepath = os.path.join(filepath_dir, imagepath)

	name = meta.get('name', os.path.basename(filepath)[:-len('.json')])

	image = Image.open(imagepath)

	if image.mode == 'P':
		image = image.convert('RGBA')

	if 'subimage' in meta:
		x, y, dx, dy = meta['subimage']
		image = image.crop((x, y, x + dx, y + dy))

	tiles = image_to_tiles(image, meta['palette'], meta.get('length'), meta.get('tall_sprites'))
	text = tiles_to_text(filepath, tiles)

	outpath_dir = os.path.join(outdir, os.path.relpath(filepath_dir, targetdir))
	outpath = os.path.join(outpath_dir, '{}.asm'.format(name))

	if not os.path.isdir(outpath_dir):
		os.makedirs(outpath_dir)
	with open(outpath, 'w') as f:
		f.write(text)


def hashable(value):
	return tuple(value) if isinstance(value, list) else value


def image_to_tiles(image, palette, length=None, tall_sprites=False):
	width, height = image.size

	if len(palette) != 4:
		raise ValueError("palette must be exactly 4 items")
	palette = {hashable(value): index for index, value in enumerate(palette)}

	if tall_sprites:
		rows_cols = [
			(2 * r + half, c)
			for r in range(height / 16)
			for c in range(height / 8)
			for half in (0, 1)
		]
	else:
		rows_cols = [(r, c) for r in range(height/8) for c in range(width/8)]

	if length is None:
		length = len(rows_cols)

	tiles = [
		extract_tile(image, row, col, palette)
		for row, col in rows_cols[:length]
	]

	return tiles


def extract_tile(image, row, col, palette):
	tile = []
	for y in range(row * 8, (row + 1) * 8):
		line = []
		for x in range(col * 8, (col + 1) * 8):
			pixel = image.getpixel((x, y))
			if pixel not in palette:
				raise Exception("Pixel ({}, {}) = {} is not a value in the palette".format(x, y, pixel))
			value = palette[pixel]
			line.append(value)
		tile.append(line)
	return tile


def tiles_to_text(filepath, tiles):
	tiles = '\n\n'.join(tile_to_text(tile) for tile in tiles)
	return "; Generated from {}\n\n{}\n".format(filepath, tiles)


def tile_to_text(tile):
	return '\n'.join(
		"dw `{}".format(''.join(map(str, line)))
		for line in tile
	)


if __name__ == '__main__':
	import argh
	argh.dispatch_command(main)
