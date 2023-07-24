module main

import rand

const bar_width_scale = 40

struct Histogram {
	bins int
	max  f64
	min  f64
	diff f64
	step f64
mut:
	counts []int
	n      int
}

[params]
struct HistConfig {
	bins int
	max  f64
	min  f64
}

fn Histogram.with_bins(config HistConfig) !Histogram {
	diff := config.max - config.min
	if diff <= 0 || config.bins <= 0 {
		return error('invalid config')
	}

	return Histogram{
		bins: config.bins
		max: config.max
		min: config.min
		diff: diff
		step: f64(config.max - config.min) / f64(config.bins)
		counts: []int{len: config.bins}
	}
}

fn (mut h Histogram) add(value f64) ! {
	if value < h.min {
		h.counts[0]++
	}
	if value >= h.max {
		h.counts[h.bins - 1]++
	}

	bin := int(f64(value - h.min) * h.bins / h.diff)

	// Find a safe bin index
	target := if bin < 0 {
		0
	} else if bin >= h.bins {
		h.bins - 1
	} else {
		bin
	}

	h.counts[target]++
	h.n++
}

fn (h Histogram) print() {
	println('')
	count_max := h.n / h.bins
	for i, count in h.counts {
		line := '*'.repeat(ilerp(count, 0, count_max))

		lval := i64(i * h.step + h.min)
		rval := i64((i + 1) * h.step + h.min - 1)

		println('${lval:3d}-${rval:3d}: ${line}')
	}
	println('')
}

fn ilerp(x int, a int, b int) int {
	return (x - a) * bar_width_scale / (b - a)
}

fn main() {
	// The properties of the normal distribution
	mu := 500
	sigma := 120
	scale := 3.5

	// The histogram configuration
	config := HistConfig{
		bins: 50
		max: mu + sigma * scale
		min: mu - sigma * scale
	}

	// Number of samples
	n := 20000

	mut rng := rand.new_default()

	mut hist := Histogram.with_bins(config)!

	for _ in 0 .. n {
		x, y := rng.normal_pair(mu: mu, sigma: sigma)!
		hist.add(x)!
		hist.add(y)!
	}

	hist.print()
}
