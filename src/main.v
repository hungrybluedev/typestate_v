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

	println('Number of parsed files: ${context.path_ast_map.len}\n\n')

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
	protocol_file := context.path_ast_map[os.join_path(directory, 'protocol.v')] or {
		return error('Could not open protocol file.')
	}
	protocol_statements := protocol_file.stmts

	// For now, we only support only one protocol per file
	discovered_protocol := extract_protocol(protocol_statements)!

	// Validate protocols
	// Make sure the state type mentioned in the rules is the same as the one we found

	println('Relevant types:')
	mut target_type := &ast.TypeSymbol{}
	mut original_automata := TypestateAutomata{}
	mut just_name := ''

	for symbol in context.builder.table.type_symbols {
		if symbol.idx == discovered_protocol.full_type {
			println('${symbol.name} (${symbol.idx})')
			full_name := symbol.name

			rest := full_name.all_after(symbol.symbol_name_except_generic()).trim('[]').split(',').map(it.trim_space())

			target_type, _ = context.builder.table.find_sym_and_type_idx(rest[0])
			// mut target_states, _ := context.builder.table.find_sym_and_type_idx(rest[1])
			just_name = target_type.name.all_after_first(target_type.mod + '.')

			mut mentioned_methods := map[string]bool{}

			// Iterate over the rules and check if the mentioned methods are present in the protocol
			for rule in discovered_protocol.rules {
				if rule.stimulus in mentioned_methods {
				}
				if rule.stimulus !in mentioned_methods {
					mentioned_methods[rule.stimulus.all_after_first('.')] = true
				}
			}

			// Make sure that all the methods of the target type are mentioned in the protocol rules.
			for function in target_type.methods {
				if function.name !in mentioned_methods {
					return error('Method ${function.name} is not mentioned in the protocol.')
				}
			}

			// Make sure we have all the states mentioned in the protocol rules
			for rule in discovered_protocol.rules {
				if !discovered_protocol.has_state(rule.start) {
					return error('State ${rule.start} is not mentioned in the protocol.')
				}
				if !discovered_protocol.has_state(rule.end) {
					return error('State ${rule.end} is not mentioned in the protocol.')
				}
			}

			original_automata = TypestateAutomata.build(discovered_protocol)!
		}
	}
	println("\n\nFinding the main function' statements:")
	main_fn := context.builder.table.fns['main.main']

	main_statements, main_file := context.get_statements_for(main_fn)!

	mut reference_map := map[string]&TypestateAutomata{}

	for statement in main_statements {
		if statement is ast.AssignStmt && (statement.op == .decl_assign || statement.op == .assign)
			&& statement.right_types.len == 1 {
			assigned_type := statement.right_types[0]
			if assigned_type == target_type.idx {
				// We found a target type being instantiated
				identifier := (statement.left[0] as ast.Ident).name

				if statement.op == .decl_assign && identifier in reference_map {
					return error('Cannot perform re-declaration.')
				}

				mut automata := original_automata.clone_ref()
				reference_map[identifier] = automata

				right_expression := statement.right[0]
				if right_expression is ast.CallExpr {
					call_expr := right_expression as ast.CallExpr

					automata.accept('${just_name}.${call_expr.name}') or {
						return error(serialise_state_error(err, main_file, call_expr.pos.line_nr))
					}
				}
			}
		} else if statement is ast.ExprStmt && !statement.is_expr && statement.expr is ast.CallExpr
			&& (statement.expr as ast.CallExpr).left_type == target_type.idx {
			call_expr := statement.expr as ast.CallExpr
			identifier := (call_expr.left as ast.Ident).name

			if identifier !in reference_map {
				return error('Instance of ${target_type.name} identified as ${identifier} is not initialized.')
			}

			mut automata := reference_map[identifier] or {
				return error('Could not find the automata for ${identifier}.')
			}

			automata.accept('${just_name}.${call_expr.name}') or {
				return error(serialise_state_error(err, main_file, call_expr.pos.line_nr))
			}

			// update the automata in the map
			// reference_map[identifier] = automata
		}
		// TODO: Handle static functions
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
		]
	}
	app.setup()
	app.parse(os.args)
}
