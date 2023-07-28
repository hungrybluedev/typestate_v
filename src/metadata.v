module main

import v.vmod

const manifest = vmod.from_file('v.mod') or { panic(err) }

pub const (
	version     = manifest.version
	name        = manifest.name
	description = manifest.description
	help_string = 'A simple command line tool for typestate checking in V.'
	usage       = 'typestate_v [directory]\ntypestate_v help'
)
