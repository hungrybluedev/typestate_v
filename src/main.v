module main

import v.ast
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

	mut path_ast_map := map[string]&ast.File{}
	for ast in context.builder.parsed_files {
		path_ast_map[ast.path] = ast
	}
	println('Number of parsed files: ${path_ast_map.len}\n\n')

	// functions := context.builder.table.fns.clone()
	// for name, function in functions {
	// if name.contains('main') {
	// 	println('${name}: ${function.file}')
	// 	target_file := path_ast_map[function.file] or { panic('Could not find the file.') }
	// 	for stmt in target_file.stmts {
	// 		if stmt is ast.FnDecl && stmt.name == name {
	// 			for real_stmt in stmt.stmts {
	// 				println(real_stmt)
	// 				if real_stmt is ast.AssignStmt {
	// 					println(real_stmt.op)
	// 					println(real_stmt.right_types.map(it.str()))
	// 				}
	// 			}
	// 		}
	// 	}
	// }
	// }

	// Register types and protocols

	// We expect to find a protocol.v file in the directory
	// If we don't find it, we return an error
	protocol_file := path_ast_map[os.join_path(directory, 'protocol.v')] or {
		return error('Could not open protocol file.')
	}
	protocol_statements := protocol_file.stmts

	// For now, we only support only one protocol per file
	discovered_protocol := extract_protocol(protocol_statements)!

	// dump(discovered_protocol)

	// Validate protocols
	// Make sure the state type mentioned in the rules is the same as the one we found

	println('Relevant types:')
	// dump(context.builder.table.type_symbols)
	for symbol in context.builder.table.type_symbols {
		if symbol.idx == discovered_protocol.full_type {
			println('${symbol.name} (${symbol.idx})')
			full_name := symbol.name

			dump(symbol.symbol_name_except_generic())

			rest := full_name.all_after(symbol.symbol_name_except_generic()).trim('[]').split(',').map(it.trim_space())
			for name in rest {
				println(context.builder.table.find_sym_and_type_idx(name))
			}
			// find_sym_and_type_idx
		}
	}
	// println('\n\nRelevant statements:')
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
		]
	}
	app.setup()
	app.parse(os.args)
}
