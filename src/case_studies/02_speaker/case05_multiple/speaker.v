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
	mut s1 := Speaker{}
	mut s2 := Speaker{}

	// Invalid: must turn on speaker before adjusting volume
	// s.turn_low()

	// All of these are valid
	s1.turn_on()
	s2.turn_on()
	s1.turn_low()
	s2.turn_high()
	s1.turn_high()
	s2.turn_low()
	s1.turn_off()
	s2.turn_off()

	s1.turn_on()
	s2.turn_on()
	s2.turn_off()
	s1.turn_high()
	s2.turn_high()
	s1.turn_off()

	s1.turn_on()
	s1.turn_low()
	s1.turn_off()
}
