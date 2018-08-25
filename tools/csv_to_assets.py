import csv
import json
import os

from PIL import Image

def main(filename, tall=False, image='entities.png', palettepath='include/palettes.asm'):
	table = csv.reader([line for line in open(filename) if not line.startswith('#')])
	palettes = get_palettes(image)
	sprite_palettes = render_palettes(palettes[:8])
	tile_palettes = render_palettes(palettes[8:])
	with open(palettepath, 'w') as f:
		f.write("""
SpritePalettes:
{}

TilePalettes:
{}
""".format(sprite_palettes, tile_palettes))

	size = 16 if tall else 8
	for row in table:
		name, x, y, palette = row
		x, y, palette = map(int, (x, y, palette))
		obj = {
			'image': image,
			'palette': palettes[palette],
			'tall_sprites': tall,
			'subimage': [x * size, y * size, size, size],
		}
		with open('assets/{}.json'.format(name), 'w') as f:
			f.write(json.dumps(obj, indent=4) + '\n')
		flags = palette % 8
		with open('include/assets/flags_{}.asm'.format(name), 'w') as f:
			f.write("db %{:>08}".format(bin(flags)[2:]))


def get_palettes(imagepath):
	image = Image.open(os.path.join('assets', imagepath))
	if image.mode == 'P':
		image = image.convert('RGBA')
	return [
		[
			image.getpixel((x, y))
			for x in range(4)
		] for y in range(16)
	]


def render_palettes(palettes):
	lines = []
	for palette in palettes:
		palette = map(map_color, palette)
		lines.append("\tdw {}".format(
			', '.join(
				'%{:>015}'.format(bin(color)[2:])
				for color in palette
			)
		))
	return '\n'.join(lines)


def map_color(color):
	try:
		iter(color)
	except TypeError:
		# not iterable -> greyscale -> copy evenly to rgb
		color = color, color, color
	if len(color) == 4:
		# RGBA -> drop A
		color = color[:3]

	r, g, b = color
	# convert to perfect (float, possibly out of range) GBC values.
	# conversion taken from the other direction in gambatte and linear equation solved to invert
	color = (
		(31*r - 5*g - b) / 200.,
		(3*r + 35*g - 13*b) / 200.,
		(-9*r - 5*g + 39*b) / 200.
	)
	# as a very rough estimate, we simply round and clamp each value
	color = [
		max(0, min(31, int(round(value))))
		for value in color
	]
	assert all(value in range(32) for value in color)

	print "Mapped color {} to {}".format([r, g, b], color)

	r, g, b = color
	return r + (g << 5) + (b << 10)


if __name__ == '__main__':
	import argh
	argh.dispatch_command(main)
