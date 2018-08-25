
from collections import namedtuple

from bs4 import BeautifulSoup


Step = namedtuple('Step', ['duration', 'pitch'])


def convert(filename, frames_per_beat):
	with open(filename) as f:
		root = BeautifulSoup(f, "xml")

	# As a simple way to approximate releasing the note between notes,
	# we add an implicit rest of a 32nd of a beat at the end of each beat,
	# unless it's shorter than 1/16th
	END_REST = 1/32.
	END_REST_THRESHOLD = 1/16.

	parts = []

	score = getattr(root, 'score-partwise')
	for part in score('part', recursive=False):
		steps = []
		parts.append(steps)
		for measure in part('measure', recursive=False):
			for note in measure('note', recursive=False):
				duration = int(note.duration.string) / 256.
				if note('rest', recursive=False):
					steps.append(Step(duration, '0'))
				else:
					pitch = "NOTE_{}{}{}".format(
						note.pitch.step.string,
						(
							{"-1": "b", "1": "s"}[note.pitch.alter.string]
							if note.pitch('alter', recursive=False) else ""
						),
						note.pitch.octave.string,
					)
					if duration > END_REST_THRESHOLD:
						assert duration > END_REST
						steps.append(Step(duration - END_REST, pitch))
						steps.append(Step(END_REST, '0'))
					else:
						steps.append(Step(duration, pitch))
		print "Got part with {} steps".format(len(steps))

	# Regroup steps into a step for each unique triplet of pitches
	beat_steps = []
	first = lambda part: part[0] if part else Step(float('inf'), '0')
	while any(parts):
		# work out time to next change
		next = min(first(part).duration for part in parts)
		# record this step
		beat_steps.append((next,) + tuple(first(part).pitch for part in parts))
		# reduce or remove leading step for each part
		for part in parts:
			if not part:
				continue
			if part[0].duration == next:
				part.pop(0)
			else:
				part[0] = part[0]._replace(duration=part[0].duration - next)

	print "Regrouped into {} steps".format(len(beat_steps))

	# Convert step durations from beats to frames.
	# Remove any steps that end up with a duration of 0 frames
	frame_steps = []
	frame = 0
	for step in beat_steps:
		beats, pitches = step[0], step[1:]
		frames = beats * frames_per_beat
		# quantize
		end_frame = frame + frames
		frames = int(end_frame) - int(frame)
		frame = end_frame
		if not frames:
			print "Dropping step that would be less than a frame long"
			continue
		frame_steps.append((frames,) + pitches)

	# Convert to text
	lines = ["\tStep {}".format(', '.join(map(str, step))) for step in frame_steps]
	return lines


def main(name, infile, outfile, frames_per_beat=31):
	lines = convert(infile, frames_per_beat)
	with open(outfile, 'w') as f:
		f.write('include "freq.asm"\n')
		f.write('\n')
		f.write('{}:\n'.format(name))
		f.write('{}\n'.format('\n'.join(lines)))
		f.write('\tEndSong {}\n'.format(name))


if __name__ == '__main__':
	import argh
	argh.dispatch_command(main)
