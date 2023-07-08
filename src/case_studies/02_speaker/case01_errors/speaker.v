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
