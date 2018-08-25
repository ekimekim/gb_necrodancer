import csv
import json
import os

from PIL import Image

def main(filename, tall=False, image='entities.png', pallettepath='include/pallettes.asm'):
	table = csv.reader([line for line in open(filename) if not line.startswith('#')])
	pallettes = get_pallettes(image)
	sprite_pallettes = render_pallettes(pallettes[:8])
	tile_pallettes = render_pallettes(pallettes[8:])
	with open(pallettepath, 'w') as f:
		f.write("""
SpritePallettes:
{}

TilePallettes:
{}
""".format(sprite_pallettes, tile_pallettes))

	size = 16 if tall else 8
	for row in table:
		name, x, y, pallette = row
		x, y, pallette = map(int, (x, y, pallette))
		obj = {
			'image': image,
			'pallette': pallettes[pallette],
			'tall_sprites': tall,
			'subimage': [x * size, y * size, size, size],
		}
		with open('assets/{}.json'.format(name), 'w') as f:
			f.write(json.dumps(obj, indent=4) + '\n')


def get_pallettes(imagepath):
	image = Image.open(os.path.join('assets', imagepath))
	if image.mode == 'P':
		image = image.convert('RGBA')
	return [
		[
			image.getpixel((x, y))
			for x in range(4)
		] for y in range(16)
	]


def render_pallettes(pallettes):
	lines = []
	for pallette in pallettes:
		pallette = map(map_color, pallette)
		lines.append("\tdw {}".format(
			', '.join(
				'%{:>015}'.format(bin(color)[2:])
				for color in pallette
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
