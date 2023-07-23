module main

import v.ast

fn (mut context TypestateContext) validate_protocol() ! {
	for symbol in context.builder.table.type_symbols {
		if symbol.idx == context.discovered_protocol.full_type {
			// println('${symbol.name} (${symbol.idx})')
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

fn (mut context TypestateContext) check_statements(statements []ast.Stmt, fn_file string) ! {
	for statement in statements {
		// println('${statement.type_name()}\t${statement}')

		match statement {
			ast.AssignStmt {
				if statement.right_types.len == 1
					&& statement.right_types[0] == context.target_type.idx {
					// We found a target type being instantiated
					identifier := (statement.left[0] as ast.Ident).name

					if statement.op == .decl_assign && identifier in context.reference_map {
						return error('Cannot perform re-declaration.')
					}

					mut automata := context.original_automata.clone_ref()
					context.reference_map[identifier] = automata

					right_expression := statement.right[0]
					if right_expression is ast.CallExpr {
						call_expr := right_expression as ast.CallExpr

						automata.accept('${context.just_name}.${call_expr.name}') or {
							return error(serialise_state_error(err, fn_file, call_expr.pos.line_nr))
						}
					}
				} else {
					for expr in statement.right {
						context.check_expression(expr, fn_file)!
					}
				}
			}
			ast.ExprStmt {
				context.check_expression(statement.expr, fn_file)!
			}
			ast.ForStmt {
				context.check_statements(statement.stmts, fn_file)!
			}
			ast.Return {
				for expr in statement.exprs {
					context.check_expression(expr, fn_file)!
				}
			}
			else {
				// unsupported statement type
				println('UNSUPPORTED: ${statement.type_name()}\t${statement}')
			}
		}
	}
}

fn (mut context TypestateContext) check_expression(expression ast.Expr, fn_file string) ! {
	match expression {
		ast.CallExpr {
			call_expr := expression as ast.CallExpr
			if call_expr.left_type == context.target_type.idx {
				identifier := (call_expr.left as ast.Ident).name

				if identifier !in context.reference_map {
					return error('Instance of ${context.target_type.name} identified as ${identifier} is not initialized.')
				}

				mut automata := context.reference_map[identifier] or {
					return error('Could not find the automata for ${identifier}.')
				}

				automata.accept('${context.just_name}.${call_expr.name}') or {
					return error(serialise_state_error(err, fn_file, call_expr.pos.line_nr))
				}

				// Check the statements inside the method
				method := context.target_type.find_method(call_expr.name) or {
					return error('Could not find the method ${call_expr.name} in ${context.target_type.name}.')
				}
				method_name := context.just_name + '.' + method.name

				if method_name !in context.visited_functions {
					context.visited_functions[method_name] = true

					// Check the receiver type of the method
					receiver_name := method.params[0].name

					// Add a sub-automata for the receiver
					sub_automata := automata.clone_ref()
					context.reference_map[receiver_name] = sub_automata

					context.check_function(method)!

					// Remove the sub-automata
					context.reference_map.delete(receiver_name)
				}
			} else {
				// It was not a method. Check everything
				for arg in call_expr.args {
					context.check_expression(arg.expr, fn_file)!
				}
				fn_name := call_expr.name
				if fn_name in context.builder.table.fns && fn_name !in context.visited_functions {
					context.visited_functions[fn_name] = true
					context.check_function(context.builder.table.fns[fn_name])!
				}
			}
		}
		else {
			// unsupported expression type
			println('UNSUPPORTED: ${expression.type_name()}\t${expression}')
		}
	}
}

fn (mut context TypestateContext) check_function(function ast.Fn) ! {
	statements, fn_file := context.get_statements_for(function)!
	context.check_statements(statements, fn_file)!
}
