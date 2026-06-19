## Procedural sound-effect generator — a faithful GDScript port of DrPetter's
## sfxr (the classic 8-bit SFX synth, public domain).
##
## Synthesizes retro game sounds at runtime with ZERO audio assets: pickups,
## lasers, explosions, power-ups, hits, jumps, blips. Returns an
## [AudioStreamWAV] you can drop straight into any AudioStreamPlayer — or let
## Juicee's presets play them automatically.
##
## [codeblock]
## var coin := JuiceeSfxr.make(JuiceeSfxr.Category.PICKUP_COIN)
## $AudioStreamPlayer.stream = coin
## $AudioStreamPlayer.play()
## [/codeblock]
##
## A fixed `seed_value` reproduces the exact same sound every time; pass 0 for a
## fresh random variation on each call.
##
## @experimental: Procedural SFX is an experimental prototyping aid producing
## 8-bit / chiptune-quality sound. The API may change in a future release; for
## shipping audio prefer hand-crafted assets played via [JuiceeSoundEffect].
@tool
class_name JuiceeSfxr
extends RefCounted

enum Category {
	PICKUP_COIN, ## Coin / item pickup — bright blip with optional arpeggio sparkle.
	LASER_SHOOT, ## Laser / projectile — downward frequency sweep.
	EXPLOSION,   ## Explosion / death — noise burst with punch.
	POWERUP,     ## Power-up / level-up — rising tone, often repeating.
	HIT_HURT,    ## Hit / hurt — short harsh downward zap.
	JUMP,        ## Jump — square wave upward chirp.
	BLIP_SELECT, ## UI blip / menu select — tiny clean tick.
	RANDOM,      ## Fully randomized — different every seed.
}

# ─── sfxr parameters (all normalized, mostly 0..1) ───────────────────────────
var wave_type: int = 0          # 0 square, 1 sawtooth, 2 sine, 3 noise
var p_env_attack: float = 0.0
var p_env_sustain: float = 0.3
var p_env_punch: float = 0.0
var p_env_decay: float = 0.4
var p_base_freq: float = 0.3
var p_freq_limit: float = 0.0
var p_freq_ramp: float = 0.0
var p_freq_dramp: float = 0.0
var p_vib_strength: float = 0.0
var p_vib_speed: float = 0.0
var p_arp_mod: float = 0.0
var p_arp_speed: float = 0.0
var p_duty: float = 0.0
var p_duty_ramp: float = 0.0
var p_repeat_speed: float = 0.0
var p_pha_offset: float = 0.0
var p_pha_ramp: float = 0.0
var p_lpf_freq: float = 1.0
var p_lpf_ramp: float = 0.0
var p_lpf_resonance: float = 0.0
var p_hpf_freq: float = 0.0
var p_hpf_ramp: float = 0.0
var p_sound_vol: float = 0.5

const _SELF := preload("res://addons/juicee/audio/juicee_sfxr.gd")
var _rng := RandomNumberGenerator.new()
## When true, the whole buffer is scaled down so its peak hits [member target_peak]
## instead of hard-clipping (faithful sfxr doubles via the phaser and would clip).
var normalize := true
var target_peak := 0.95
const SAMPLE_RATE := 44100
const MASTER_VOLUME := 1.0

func _init() -> void:
	_rng.randomize()

# ─── Static convenience ──────────────────────────────────────────────────────

## Generate a sound of [param category]. [param seed_value] of 0 = fresh random
## variation; any non-zero value reproduces the same sound every time.
static func make(category: Category, seed_value: int = 0) -> AudioStreamWAV:
	var g := _SELF.new()
	if seed_value != 0:
		g._rng.seed = seed_value
	match category:
		Category.PICKUP_COIN: g.preset_pickup_coin()
		Category.LASER_SHOOT: g.preset_laser_shoot()
		Category.EXPLOSION:   g.preset_explosion()
		Category.POWERUP:     g.preset_powerup()
		Category.HIT_HURT:    g.preset_hit_hurt()
		Category.JUMP:        g.preset_jump()
		Category.BLIP_SELECT: g.preset_blip_select()
		Category.RANDOM:      g.preset_random()
	return g.generate()

# ─── Randomization helpers (match sfxr's frnd / rnd) ─────────────────────────

func _frnd(range_max: float) -> float:
	return _rng.randf() * range_max

func _rnd(n: int) -> int:
	return _rng.randi() % (n + 1)

func _reset_params() -> void:
	wave_type = 0
	p_env_attack = 0.0; p_env_sustain = 0.3; p_env_punch = 0.0; p_env_decay = 0.4
	p_base_freq = 0.3; p_freq_limit = 0.0; p_freq_ramp = 0.0; p_freq_dramp = 0.0
	p_vib_strength = 0.0; p_vib_speed = 0.0
	p_arp_mod = 0.0; p_arp_speed = 0.0
	p_duty = 0.0; p_duty_ramp = 0.0
	p_repeat_speed = 0.0
	p_pha_offset = 0.0; p_pha_ramp = 0.0
	p_lpf_freq = 1.0; p_lpf_ramp = 0.0; p_lpf_resonance = 0.0
	p_hpf_freq = 0.0; p_hpf_ramp = 0.0
	p_sound_vol = 0.5

# ─── Preset parameter recipes (ported from sfxr) ─────────────────────────────

func preset_pickup_coin() -> void:
	_reset_params()
	p_base_freq = 0.4 + _frnd(0.5)
	p_env_attack = 0.0
	p_env_sustain = _frnd(0.1)
	p_env_decay = 0.1 + _frnd(0.4)
	p_env_punch = 0.3 + _frnd(0.3)
	if _rnd(1) == 1:
		p_arp_speed = 0.5 + _frnd(0.2)
		p_arp_mod = 0.2 + _frnd(0.4)

func preset_laser_shoot() -> void:
	_reset_params()
	wave_type = _rnd(2)
	if wave_type == 2 and _rnd(1) == 1:
		wave_type = _rnd(1)
	p_base_freq = 0.5 + _frnd(0.5)
	p_freq_limit = p_base_freq - 0.2 - _frnd(0.6)
	if p_freq_limit < 0.2:
		p_freq_limit = 0.2
	p_freq_ramp = -0.15 - _frnd(0.2)
	if _rnd(2) == 0:
		p_base_freq = 0.3 + _frnd(0.6)
		p_freq_limit = _frnd(0.1)
		p_freq_ramp = -0.35 - _frnd(0.3)
	if _rnd(1) == 1:
		p_duty = _frnd(0.5)
		p_duty_ramp = _frnd(0.2)
	else:
		p_duty = 0.4 + _frnd(0.5)
		p_duty_ramp = -_frnd(0.7)
	p_env_attack = 0.0
	p_env_sustain = 0.1 + _frnd(0.2)
	p_env_decay = _frnd(0.4)
	if _rnd(1) == 1:
		p_env_punch = _frnd(0.3)
	if _rnd(2) == 0:
		p_pha_offset = _frnd(0.2)
		p_pha_ramp = -_frnd(0.2)
	if _rnd(1) == 1:
		p_hpf_freq = _frnd(0.3)

func preset_explosion() -> void:
	_reset_params()
	wave_type = 3
	p_base_freq = 0.1 + _frnd(0.4)
	p_freq_ramp = -0.1 + _frnd(0.4)
	p_env_attack = 0.0
	p_env_sustain = 0.1 + _frnd(0.3)
	p_env_decay = _frnd(0.5)
	if _rnd(1) == 0:
		p_pha_offset = -0.3 + _frnd(0.9)
		p_pha_ramp = -_frnd(0.3)
	p_env_punch = 0.2 + _frnd(0.6)
	if _rnd(1) == 1:
		p_vib_strength = _frnd(0.7)
		p_vib_speed = _frnd(0.6)
	if _rnd(2) == 0:
		p_arp_speed = 0.6 + _frnd(0.3)
		p_arp_mod = 0.8 - _frnd(1.6)

func preset_powerup() -> void:
	_reset_params()
	if _rnd(1) == 1:
		wave_type = 1
	else:
		p_duty = _frnd(0.6)
	if _rnd(1) == 1:
		p_base_freq = 0.2 + _frnd(0.3)
		p_freq_ramp = 0.1 + _frnd(0.4)
		p_repeat_speed = 0.4 + _frnd(0.4)
	else:
		p_base_freq = 0.2 + _frnd(0.3)
		p_freq_ramp = 0.05 + _frnd(0.2)
		if _rnd(1) == 1:
			p_vib_strength = _frnd(0.7)
			p_vib_speed = _frnd(0.6)
	p_env_attack = 0.0
	p_env_sustain = _frnd(0.4)
	p_env_decay = 0.1 + _frnd(0.4)

func preset_hit_hurt() -> void:
	_reset_params()
	wave_type = _rnd(2)
	if wave_type == 2:
		wave_type = 3
	if wave_type == 0:
		p_duty = _frnd(0.6)
	p_base_freq = 0.2 + _frnd(0.6)
	p_freq_ramp = -0.3 - _frnd(0.4)
	p_env_attack = 0.0
	p_env_sustain = _frnd(0.1)
	p_env_decay = 0.1 + _frnd(0.2)
	if _rnd(1) == 1:
		p_hpf_freq = _frnd(0.3)

func preset_jump() -> void:
	_reset_params()
	wave_type = 0
	p_duty = _frnd(0.6)
	p_base_freq = 0.3 + _frnd(0.3)
	p_freq_ramp = 0.1 + _frnd(0.2)
	p_env_attack = 0.0
	p_env_sustain = 0.1 + _frnd(0.3)
	p_env_decay = 0.1 + _frnd(0.2)
	if _rnd(1) == 1:
		p_hpf_freq = _frnd(0.3)
	if _rnd(1) == 1:
		p_lpf_freq = 1.0 - _frnd(0.6)

func preset_blip_select() -> void:
	_reset_params()
	wave_type = _rnd(1)
	if wave_type == 0:
		p_duty = _frnd(0.6)
	p_base_freq = 0.2 + _frnd(0.4)
	p_env_attack = 0.0
	p_env_sustain = 0.1 + _frnd(0.1)
	p_env_decay = _frnd(0.2)
	p_hpf_freq = 0.1

func preset_random() -> void:
	_reset_params()
	wave_type = _rnd(3)
	p_base_freq = pow(_frnd(2.0) - 1.0, 2.0)
	if _rnd(1) == 1:
		p_base_freq = pow(_frnd(2.0) - 1.0, 3.0) + 0.5
	p_freq_limit = 0.0
	p_freq_ramp = pow(_frnd(2.0) - 1.0, 5.0)
	if p_base_freq > 0.7 and p_freq_ramp > 0.2:
		p_freq_ramp = -p_freq_ramp
	if p_base_freq < 0.2 and p_freq_ramp < -0.05:
		p_freq_ramp = -p_freq_ramp
	p_freq_dramp = pow(_frnd(2.0) - 1.0, 3.0)
	p_duty = _frnd(2.0) - 1.0
	p_duty_ramp = pow(_frnd(2.0) - 1.0, 3.0)
	p_vib_strength = pow(_frnd(2.0) - 1.0, 3.0)
	p_vib_speed = _frnd(2.0) - 1.0
	p_env_attack = pow(_frnd(2.0) - 1.0, 3.0)
	p_env_sustain = pow(_frnd(2.0) - 1.0, 2.0)
	p_env_decay = _frnd(2.0) - 1.0
	p_env_punch = pow(_frnd(0.8), 2.0)
	if p_env_attack + p_env_sustain + p_env_decay < 0.2:
		p_env_sustain += 0.2 + _frnd(0.3)
	p_lpf_resonance = _frnd(2.0) - 1.0
	p_lpf_freq = 1.0 - pow(_frnd(1.0), 3.0)
	p_lpf_ramp = pow(_frnd(2.0) - 1.0, 3.0)
	if p_lpf_freq < 0.1 and p_lpf_ramp < -0.05:
		p_lpf_ramp = -p_lpf_ramp
	p_hpf_freq = pow(_frnd(1.0), 5.0)
	p_hpf_ramp = pow(_frnd(2.0) - 1.0, 5.0)
	p_pha_offset = pow(_frnd(2.0) - 1.0, 3.0)
	p_pha_ramp = pow(_frnd(2.0) - 1.0, 3.0)
	p_repeat_speed = _frnd(1.0)
	p_arp_speed = _frnd(2.0) - 1.0
	p_arp_mod = _frnd(2.0) - 1.0

# ─── Synthesis ───────────────────────────────────────────────────────────────

## Render the current parameters to a mono 16-bit [AudioStreamWAV].
func generate() -> AudioStreamWAV:
	var fperiod := 100.0 / (p_base_freq * p_base_freq + 0.001)
	var period := int(fperiod)
	var fmaxperiod := 100.0 / (p_freq_limit * p_freq_limit + 0.001)
	var fslide := 1.0 - pow(p_freq_ramp, 3.0) * 0.01
	var fdslide := -pow(p_freq_dramp, 3.0) * 0.000001
	var square_duty := 0.5 - p_duty * 0.5
	var square_slide := -p_duty_ramp * 0.00005

	var arp_mod := 0.0
	if p_arp_mod >= 0.0:
		arp_mod = 1.0 - pow(p_arp_mod, 2.0) * 0.9
	else:
		arp_mod = 1.0 + pow(p_arp_mod, 2.0) * 10.0
	var arp_time := 0
	var arp_limit := int(pow(p_arp_speed, 2.0) * 20000 + 32)
	if p_arp_speed == 1.0:
		arp_limit = 0

	# Low-pass / high-pass filter state.
	var fltp := 0.0
	var fltdp := 0.0
	var fltw := pow(p_lpf_freq, 3.0) * 0.1
	var fltw_d := 1.0 + p_lpf_ramp * 0.0001
	var fltdmp := 5.0 / (1.0 + pow(p_lpf_resonance, 2.0) * 20.0) * (0.01 + fltw)
	if fltdmp > 0.8:
		fltdmp = 0.8
	var fltphp := 0.0
	var flthp := pow(p_hpf_freq, 2.0) * 0.1
	var flthp_d := 1.0 + p_hpf_ramp * 0.0003

	# Vibrato.
	var vib_phase := 0.0
	var vib_speed := pow(p_vib_speed, 2.0) * 0.01
	var vib_amp := p_vib_strength * 0.5

	# Volume envelope.
	var env_vol := 0.0
	var env_stage := 0
	var env_time := 0
	var env_length := [
		int(p_env_attack * p_env_attack * 100000.0),
		int(p_env_sustain * p_env_sustain * 100000.0),
		int(p_env_decay * p_env_decay * 100000.0),
	]

	# Phaser.
	var fphase := pow(p_pha_offset, 2.0) * 1020.0
	if p_pha_offset < 0.0:
		fphase = -fphase
	var fdphase := pow(p_pha_ramp, 2.0) * 1.0
	if p_pha_ramp < 0.0:
		fdphase = -fdphase
	var iphase := absi(int(fphase))
	var ipp := 0
	var phaser_buffer := PackedFloat32Array()
	phaser_buffer.resize(1024)

	var noise_buffer := PackedFloat32Array()
	noise_buffer.resize(32)
	for i in 32:
		noise_buffer[i] = _rng.randf_range(-1.0, 1.0)

	var rep_time := 0
	var rep_limit := int(pow(p_repeat_speed, 2.0) * 20000 + 32)
	if p_repeat_speed == 0.0:
		rep_limit = 0

	var phase := 0
	var samples := PackedFloat32Array()
	var max_samples := SAMPLE_RATE * 8  # hard safety cap (8 s)
	var finished := false
	var peak := 0.0

	while not finished and samples.size() < max_samples:
		rep_time += 1
		if rep_limit != 0 and rep_time >= rep_limit:
			# Repeat: re-trigger the oscillator + arpeggio (envelope keeps going).
			rep_time = 0
			fperiod = 100.0 / (p_base_freq * p_base_freq + 0.001)
			period = int(fperiod)
			fmaxperiod = 100.0 / (p_freq_limit * p_freq_limit + 0.001)
			fslide = 1.0 - pow(p_freq_ramp, 3.0) * 0.01
			fdslide = -pow(p_freq_dramp, 3.0) * 0.000001
			square_duty = 0.5 - p_duty * 0.5
			square_slide = -p_duty_ramp * 0.00005
			if p_arp_mod >= 0.0:
				arp_mod = 1.0 - pow(p_arp_mod, 2.0) * 0.9
			else:
				arp_mod = 1.0 + pow(p_arp_mod, 2.0) * 10.0
			arp_time = 0
			arp_limit = int(pow(p_arp_speed, 2.0) * 20000 + 32)
			if p_arp_speed == 1.0:
				arp_limit = 0

		# Arpeggio.
		arp_time += 1
		if arp_limit != 0 and arp_time >= arp_limit:
			arp_limit = 0
			fperiod *= arp_mod

		# Frequency slide.
		fslide += fdslide
		fperiod *= fslide
		if fperiod > fmaxperiod:
			fperiod = fmaxperiod
			if p_freq_limit > 0.0:
				finished = true
		var rfperiod := fperiod
		if vib_amp > 0.0:
			vib_phase += vib_speed
			rfperiod = fperiod * (1.0 + sin(vib_phase) * vib_amp)
		period = int(rfperiod)
		if period < 8:
			period = 8
		square_duty = clampf(square_duty + square_slide, 0.0, 0.5)

		# Volume envelope.
		env_time += 1
		if env_time > int(env_length[env_stage]):
			env_time = 0
			env_stage += 1
			if env_stage == 3:
				finished = true
				break
		var el: int = maxi(1, int(env_length[env_stage]))
		if env_stage == 0:
			env_vol = float(env_time) / el
		elif env_stage == 1:
			env_vol = 1.0 + (1.0 - float(env_time) / el) * 2.0 * p_env_punch
		else:
			env_vol = 1.0 - float(env_time) / el

		# Phaser step.
		fphase += fdphase
		iphase = mini(absi(int(fphase)), 1023)

		if flthp_d != 0.0:
			flthp = clampf(flthp * flthp_d, 0.00001, 0.1)

		# 8× supersampling for cleaner output.
		var ssample := 0.0
		for _si in 8:
			var sample := 0.0
			phase += 1
			if phase >= period:
				phase = phase % period
				if wave_type == 3:
					for j in 32:
						noise_buffer[j] = _rng.randf_range(-1.0, 1.0)
			var fp := float(phase) / period
			match wave_type:
				0:  # square
					sample = 0.5 if fp < square_duty else -0.5
				1:  # sawtooth
					sample = 1.0 - fp * 2.0
				2:  # sine
					sample = sin(fp * TAU)
				3:  # noise
					sample = noise_buffer[(phase * 32 / period) % 32]

			# Low-pass filter.
			var pp := fltp
			fltw = clampf(fltw * fltw_d, 0.0, 0.1)
			if p_lpf_freq != 1.0:
				fltdp += (sample - fltp) * fltw
				fltdp -= fltdp * fltdmp
			else:
				fltp = sample
				fltdp = 0.0
			fltp += fltdp
			# High-pass filter.
			fltphp += fltp - pp
			fltphp -= fltphp * flthp
			sample = fltphp

			# Phaser.
			phaser_buffer[ipp & 1023] = sample
			sample += phaser_buffer[(ipp - iphase + 1024) & 1023]
			ipp = (ipp + 1) & 1023

			ssample += sample * env_vol

		ssample = ssample / 8.0 * MASTER_VOLUME
		ssample *= 2.0 * p_sound_vol
		peak = maxf(peak, absf(ssample))
		samples.push_back(ssample)

	# Scale the whole buffer down to avoid hard-clipping; never boost quiet sounds.
	if normalize and peak > target_peak:
		var scale := target_peak / peak
		for i in samples.size():
			samples[i] *= scale

	return _to_wav(samples)

func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
