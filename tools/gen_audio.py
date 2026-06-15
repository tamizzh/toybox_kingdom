"""
gen_audio.py — synthesizes the game's sound effects + music loops from scratch
using only the Python standard library (no samples, no deps), so everything is
original and license-clean for commercial release.

Outputs 16-bit mono 22050 Hz WAVs to assets/audio/:
  SFX:   sfx_tap, sfx_count, sfx_go, sfx_collect, sfx_hit, sfx_eliminate,
         sfx_round_win, sfx_win
  Music: music_menu (relaxed loop), music_game (energetic loop)

Run:  python tools/gen_audio.py
"""
import wave, struct, math, random, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def clamp(x):
	return max(-1.0, min(1.0, x))


def osc(freq, t, wave="sine"):
	p = freq * t
	if wave == "sine":
		return math.sin(2.0 * math.pi * p)
	if wave == "square":
		return 1.0 if (p % 1.0) < 0.5 else -1.0
	if wave == "tri":
		return 2.0 * abs(2.0 * (p % 1.0) - 1.0) - 1.0
	if wave == "saw":
		return 2.0 * (p % 1.0) - 1.0
	return 0.0


def midi(n):
	return 440.0 * (2.0 ** ((n - 69) / 12.0))


class Buf:
	def __init__(self, dur):
		self.n = int(dur * SR)
		self.d = [0.0] * self.n

	def tone(self, start, dur, f0, f1=None, vol=0.3, wave="sine",
			 attack=0.006, decay=None, vib=0.0):
		if f1 is None:
			f1 = f0
		s = int(start * SR)
		L = int(dur * SR)
		e = min(self.n, s + L)
		phase = 0.0
		for i in range(e - s):
			t = i / SR
			frac = i / max(1, L)
			f = f0 + (f1 - f0) * frac
			if vib:
				f += math.sin(2.0 * math.pi * 6.0 * t) * vib
			phase += f / SR
			# oscillator on accumulated phase (phase-correct sweeps)
			if wave == "sine":
				v = math.sin(2.0 * math.pi * phase)
			elif wave == "square":
				v = 1.0 if (phase % 1.0) < 0.5 else -1.0
			elif wave == "tri":
				v = 2.0 * abs(2.0 * (phase % 1.0) - 1.0) - 1.0
			else:
				v = 2.0 * (phase % 1.0) - 1.0
			a = min(1.0, t / attack) if attack > 0 else 1.0
			if decay is None:
				tail = dur - t
				rel = min(1.0, tail / 0.02) if tail < 0.02 else 1.0
				env = a * max(0.0, rel)
			else:
				env = a * math.exp(-t / decay)
			if s + i < self.n:
				self.d[s + i] += v * vol * env

	def noise(self, start, dur, vol=0.2, decay=0.05):
		s = int(start * SR)
		e = min(self.n, s + int(dur * SR))
		for i in range(e - s):
			t = i / SR
			self.d[s + i] += random.uniform(-1, 1) * vol * math.exp(-t / decay)


def write_wav(name, buf, gain=0.85):
	peak = 1e-6
	for x in buf.d:
		if abs(x) > peak:
			peak = abs(x)
	g = gain / peak
	path = os.path.join(OUT, name + ".wav")
	w = wave.open(path, "w")
	w.setnchannels(1)
	w.setsampwidth(2)
	w.setframerate(SR)
	frames = bytearray()
	for x in buf.d:
		frames += struct.pack("<h", int(clamp(x * g) * 32767))
	w.writeframes(bytes(frames))
	w.close()
	print("GEN_OK:", path)


# ── SFX ──────────────────────────────────────────────────────────────────────
def sfx():
	b = Buf(0.07); b.tone(0, 0.06, 680, vol=0.5, wave="square", decay=0.03); write_wav("sfx_tap", b)

	b = Buf(0.14); b.tone(0, 0.12, 720, vol=0.5, wave="sine", decay=0.06); write_wav("sfx_count", b)

	b = Buf(0.30)
	b.tone(0, 0.22, 520, 1040, vol=0.5, wave="square", decay=0.14)
	b.tone(0.0, 0.22, 523, 1046, vol=0.3, wave="sine", decay=0.14)
	write_wav("sfx_go", b)

	b = Buf(0.20)
	b.tone(0.0, 0.06, midi(88), vol=0.45, wave="sine", decay=0.05)
	b.tone(0.06, 0.10, midi(93), vol=0.45, wave="sine", decay=0.07)
	write_wav("sfx_collect", b)

	b = Buf(0.22)
	b.tone(0, 0.16, 320, 70, vol=0.5, wave="saw", decay=0.09)
	b.noise(0, 0.10, vol=0.35, decay=0.05)
	write_wav("sfx_hit", b)

	b = Buf(0.42)
	b.tone(0, 0.34, 640, 130, vol=0.5, wave="square", decay=0.20)
	b.noise(0, 0.12, vol=0.2, decay=0.06)
	write_wav("sfx_eliminate", b)

	# short positive sting for a round win
	b = Buf(0.55)
	for i, nn in enumerate([72, 76, 79]):
		b.tone(i * 0.09, 0.30, midi(nn), vol=0.4, wave="tri", decay=0.22)
	write_wav("sfx_round_win", b)

	# big match fanfare
	b = Buf(1.1)
	seq = [72, 76, 79, 84, 79, 84]
	for i, nn in enumerate([72, 76, 79, 84]):
		b.tone(i * 0.11, 0.5, midi(nn), vol=0.34, wave="tri", decay=0.4)
	b.tone(0.44, 0.6, midi(84), vol=0.34, wave="sine", decay=0.45, vib=3.0)
	b.tone(0.44, 0.6, midi(88), vol=0.20, wave="tri", decay=0.45)
	write_wav("sfx_win", b)


# ── music ────────────────────────────────────────────────────────────────────
def music(name, bpm, prog, wave_lead, lead_oct, kick=True, gain=0.7):
	beat = 60.0 / bpm
	bars = len(prog)
	total = bars * 4 * beat
	b = Buf(total + 0.05)
	for bar, root in enumerate(prog):
		bt = bar * 4 * beat
		# bass: root on beats 1 and 3
		for bo in (0, 2):
			b.tone(bt + bo * beat, beat * 0.9, midi(root - 12), vol=0.30,
				   wave="tri", decay=beat * 0.6)
		# chord pad (root + maj third + fifth), soft, whole bar
		for iv in (0, 4, 7):
			b.tone(bt, beat * 3.6, midi(root + iv), vol=0.06, wave="sine",
				   decay=beat * 2.5)
		# arpeggio lead: eighth notes cycling chord tones
		arp = [0, 4, 7, 12, 7, 4, 7, 12]
		for j, iv in enumerate(arp):
			b.tone(bt + j * beat * 0.5, beat * 0.45, midi(root + lead_oct + iv),
				   vol=0.14, wave=wave_lead, decay=beat * 0.30)
		# kick thump per beat
		if kick:
			for bo in range(4):
				b.tone(bt + bo * beat, 0.08, 120, 55, vol=0.5, wave="sine",
					   decay=0.06)
	write_wav(name, b, gain)


if __name__ == "__main__":
	os.makedirs(OUT, exist_ok=True)
	sfx()
	# Relaxed menu loop in C: C major - A minor - F - G
	music("music_menu", 96, [60, 57, 65, 67], "sine", 12, kick=False, gain=0.6)
	# Energetic gameplay loop, slightly faster, brighter square lead
	music("music_game", 132, [60, 67, 69, 65], "square", 12, kick=True, gain=0.62)
	print("ALL_AUDIO_DONE")
