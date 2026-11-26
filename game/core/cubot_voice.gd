extends RefCounted
## Original nonverbal electronic chirps. No speech synthesis or external assets.
const RATE := 22050
const VOICES := {"atlas":360.0,"pixel":610.0,"mesh":440.0,"nova":520.0}
const MOODS := ["neutral","happy","curious","concerned","thinking"]
const SHAPES := {
	"neutral":[1.0,1.12,0.94,1.06],
	"happy":[1.0,1.21,1.38,1.52],
	"curious":[0.9,1.05,1.32,1.52],
	"concerned":[1.05,0.94,0.79,0.68],
	"thinking":[0.93,0.99,0.88,1.04]
}
var cache := {}

static func mood(text: String) -> String:
	var lower := text.to_lower()
	if "thinking…" in lower or "thinking..." in lower:
		return "thinking"
	for term in ["failed","error","blocked","cannot","concern","warning","risk","problema"]:
		if term in lower:
			return "concerned"
	if "?" in text:
		return "curious"
	for term in ["success","completed","great","nice","unlocked","ready","salamat","ayos"]:
		if term in lower:
			return "happy"
	return "happy" if "!" in text else "neutral"

func clip(id: String, emotion: String, text_length: int) -> AudioStreamWAV:
	var voice := id if id in VOICES else "atlas"
	var feeling := emotion if emotion in MOODS else "neutral"
	var count := clampi(2 + int(float(text_length) / 24.0), 2, 5)
	if feeling == "thinking":
		count = 2
	var key := voice + ":" + feeling + ":" + str(count)
	if cache.has(key):
		return cache[key]
	var pitches: Array = SHAPES[feeling]
	var base: float = VOICES[voice]
	var note_time := 0.105 if voice == "pixel" else (0.15 if voice == "atlas" else 0.12)
	if feeling == "thinking":
		note_time = 0.17
	elif feeling == "concerned":
		note_time += 0.035
	var note_samples := int(note_time * RATE)
	var gap_samples := int(0.035 * RATE)
	var data := PackedByteArray()
	data.resize(count * (note_samples + gap_samples) * 2)
	var cursor := 0
	for syllable in range(count):
		var pattern_index := mini(syllable, pitches.size() - 1)
		var frequency := base * float(pitches[pattern_index])
		var glide := 0.18 if feeling in ["happy","curious"] else (-0.19 if feeling == "concerned" else -0.06)
		var phase := 0.0
		for i in range(note_samples):
			var t := float(i) / float(note_samples)
			phase += TAU * frequency * (1.0 + glide * t) / RATE
			var envelope := minf(1.0, float(i) / (RATE * 0.012)) * minf(1.0, float(note_samples - i - 1) / (RATE * 0.028))
			var wobble := 0.94 + 0.06 * sin(TAU * 19.0 * float(i) / RATE)
			var wave := sin(phase) + 0.18 * sin(phase * 2.0) + 0.06 * sin(phase * 3.0)
			data.encode_s16(cursor * 2, int(wave * envelope * wobble * 7200.0))
			cursor += 1
		cursor += gap_samples
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	cache[key] = wav
	return wav
