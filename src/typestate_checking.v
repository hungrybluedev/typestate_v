module main

import v.ast

fn (mut context TypestateContext) validate_protocol() ! {
	for symbol in context.builder.table.type_symbols {
		if symbol.idx == context.discovered_protocol.full_type {
			println('${symbol.name} (${symbol.idx})')
			full_name := symbol.name

			rest := full_name.all_after(symbol.symbol_name_except_generic()).trim('[]').split(',').map(it.trim_space())

			context.target_type, _ = context.builder.table.find_sym_and_type_idx(rest[0])
			// mut target_states, _ := context.builder.table.find_sym_and_type_idx(rest[1])
			context.just_name = context.target_type.name.all_after_first(context.target_type.mod +
				'.')

			mut mentioned_methods := map[string]bool{}

			// Iterate over the rules and check if the mentioned methods are present in the protocol
			for rule in context.discovered_protocol.rules {
				if rule.stimulus in mentioned_methods {
				}
				if rule.stimulus !in mentioned_methods {
					mentioned_methods[rule.stimulus.all_after_first('.')] = true
				}
			}

			// Make sure that all the methods of the target type are mentioned in the protocol rules.
			for function in context.target_type.methods {
				if function.name !in mentioned_methods {
					return error('Method ${function.name} is not mentioned in the protocol.')
				}
			}

			// Make sure we have all the states mentioned in the protocol rules
			for rule in context.discovered_protocol.rules {
				if !context.discovered_protocol.has_state(rule.start) {
					return error('State ${rule.start} is not mentioned in the protocol.')
				}
				if !context.discovered_protocol.has_state(rule.end) {
					return error('State ${rule.end} is not mentioned in the protocol.')
				}
			}

			extracted_automata := TypestateAutomata.build(context.discovered_protocol)!
			context.original_automata = &extracted_automata
		}
	}
}

fn (mut context TypestateContext) check_function(function ast.Fn) ! {
	statements, fn_file := context.get_statements_for(function)!

	mut reference_map := map[string]&TypestateAutomata{}

	for statement in statements {
		if statement is ast.AssignStmt && (statement.op == .decl_assign || statement.op == .assign)
			&& statement.right_types.len == 1 {
			assigned_type := statement.right_types[0]
			if assigned_type == context.target_type.idx {
				// We found a target type being instantiated
				identifier := (statement.left[0] as ast.Ident).name

				if statement.op == .decl_assign && identifier in reference_map {
					return error('Cannot perform re-declaration.')
				}

				mut automata := context.original_automata.clone_ref()
				reference_map[identifier] = automata

				right_expression := statement.right[0]
				if right_expression is ast.CallExpr {
					call_expr := right_expression as ast.CallExpr

					automata.accept('${context.just_name}.${call_expr.name}') or {
						return error(serialise_state_error(err, fn_file, call_expr.pos.line_nr))
					}
				}
			}
		} else if statement is ast.ExprStmt && !statement.is_expr && statement.expr is ast.CallExpr
			&& (statement.expr as ast.CallExpr).left_type == context.target_type.idx {
			call_expr := statement.expr as ast.CallExpr
			identifier := (call_expr.left as ast.Ident).name

			if identifier !in reference_map {
				return error('Instance of ${context.target_type.name} identified as ${identifier} is not initialized.')
			}

			mut automata := reference_map[identifier] or {
				return error('Could not find the automata for ${identifier}.')
			}

			automata.accept('${context.just_name}.${call_expr.name}') or {
				return error(serialise_state_error(err, fn_file, call_expr.pos.line_nr))
			}

			// update the automata in the map
			// reference_map[identifier] = automata
		}
		// TODO: Handle static functions
	}
}
