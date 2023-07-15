module main

import os
import cli
import v.ast

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

	// println(context.builder.table)
	mut path_ast_map := map[string]&ast.File{}
	// paths := context.builder.parsed_files.map(it.path)
	// for path in paths {
	// 	println(path)
	// }
	for ast in context.builder.parsed_files {
		path_ast_map[ast.path] = ast
	}
	println('Number of parsed files: ${path_ast_map.len}\n\n')

	println('Relevant types:')
	for symbol in context.builder.table.type_symbols {
		if symbol.name.contains('Speaker') {
			println('${symbol.name} (${symbol.idx})')
		}
		if symbol.name.contains('Protocol') {
			println('${symbol.name} (${symbol.idx})')
		}
	}
	println('\n\nRelevant statements:')

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
	protocol_file := path_ast_map[os.join_path(directory, 'protocol.v')] or {
		panic('Could not open protocol file.')
	}
	protocol_statements := protocol_file.stmts

	for statement in protocol_statements {
		if statement is ast.EnumDecl {
			// Extract all the enum values
			names := statement.fields.map(it.name)
			println(names)
		}
		if statement is ast.ConstDecl {
			// Find the protocol constant
			for const_field in statement.fields {
				if const_field.name == 'main.protocol' && const_field.expr is ast.StructInit {
					println(const_field.expr.typ)
					println(const_field.expr.init_fields)
				}
			}
		}
	}

	// Validate protocols
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
