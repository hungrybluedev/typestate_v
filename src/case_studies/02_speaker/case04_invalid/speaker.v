module main

pub struct Speaker {
mut:
	volume   int
	power_on bool
}

pub fn (mut s Speaker) turn_on() {
	s.power_on = true
}

pub fn (mut s Speaker) turn_off() {
	s.power_on = false
	s.volume = 0
}

pub fn (mut s Speaker) turn_low() {
	s.volume = 3
}

pub fn (mut s Speaker) turn_high() {
	s.volume = 8
}

fn main() {
	mut s := Speaker{}

	// Invalid: must turn on speaker before adjusting volume
	s.turn_low()

	// All of these are valid
	s.turn_on()
	s.turn_low()
	s.turn_high()
	s.turn_off()

	s.turn_on()
	s.turn_high()
	s.turn_off()

	s.turn_on()
	s.turn_low()
	s.turn_off()
}
