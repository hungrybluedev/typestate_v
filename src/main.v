module main

import os
import cli

fn start(command cli.Command) ! {
	// We are guaranteed that at least one argument is present
	directory := command.args[0]

	// We check if the path exists and is a directory
	if !os.exists(directory) {
		return error('Path "${directory}" does not exist')
	}
	if !os.is_dir(directory) {
		return error('Path "${directory}" is not a directory')
	}

	// Parse the files and generate the typestate context
	mut context := TypestateContext.generate_context(directory)!

	context.precheck()!
}

fn main() {
	mut app := cli.Command{
		// Apply the metadata from v.mod and other contents mentioned in metadata.v
		name: name
		version: version
		description: description
		usage: usage
		// We define the behaviour
		execute: start // The function to execute
		required_args: 1 // The number of required arguments
		commands: []
	}
	app.setup()
	app.parse(os.args)
}
