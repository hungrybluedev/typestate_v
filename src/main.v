module main

import os
import cli

fn first_steps(command cli.Command) !TypestateContext {
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

	// println('Number of parsed files: ${context.path_ast_map.len}\n\n')

	// Register types and protocols

	// We expect to find a protocol.v file in the directory
	// If we don't find it, we return an error
	protocol_file := context.path_ast_map[os.join_path(os.real_path(directory), 'protocol.v')] or {
		return error('Could not open protocol file.')
	}
	protocol_statements := protocol_file.stmts

	// For now, we only support only one protocol per file
	context.discovered_protocol = extract_protocol(protocol_statements)!

	// Validate protocols
	// Make sure the state type mentioned in the rules is the same as the one we found

	context.validate_protocol()!

	return context
}

fn start(command cli.Command) ! {
	mut context := first_steps(command)!

	main_fn := context.builder.table.fns['main.main']

	context.check_function(main_fn)!

	// Print a notice if we found unsupported features
	if context.unsupported_count > 0 {
		println('\n\nFound ${context.unsupported_count} unsupported features.')
		println('Please contact Subhomoy Haldar (@hungrybluedev) on Discord or open an issue on GitHub.')
	}
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
		commands: [
			cli.Command{
				name: 'case-study'
				description: 'Run the TSCV on the listed case studies.'
				execute: run_for_case_studies
			},
			cli.Command{
				name: 'viz'
				description: 'Visualize the typestate graph for the given directory.'
				execute: visualize
			},
		]
	}
	app.setup()
	app.parse(os.args)
}
