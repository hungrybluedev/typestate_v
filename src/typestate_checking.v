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

fn prevent_regression(before_states map[string]TypestateState, after_states map[string]TypestateState) ! {
	if before_states != after_states {
		// Ensure that we have not regressed
		for ref, state in before_states {
			if state.index > after_states[ref].index {
				return error('State of ${ref} has regressed from ${state} to ${after_states[ref]}.')
			}
		}
	}
}

fn (mut context TypestateContext) check_statements(statements []ast.Stmt, fn_file string) ! {
	for statement in statements {
		// println('${statement.type_name()}\t${statement}')

		match statement {
			ast.BranchStmt {
				// Do nothing
			}
			ast.Block {
				context.check_statements(statement.stmts, fn_file)!
			}
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
						context.check_expression(call_expr.or_block, fn_file)!

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
				before_states := context.get_reference_states()
				context.check_statements(statement.stmts, fn_file)!
				after_states := context.get_reference_states()

				// Check if the states have changed
				prevent_regression(before_states, after_states)!
			}
			ast.Return {
				for expr in statement.exprs {
					context.check_expression(expr, fn_file)!
				}
			}
			ast.DeferStmt {
				context.check_statements(statement.stmts, fn_file)!
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
		ast.BoolLiteral, ast.IntegerLiteral, ast.FloatLiteral, ast.StringLiteral, ast.CharLiteral,
		ast.EmptyExpr, ast.Ident, ast.AtExpr {
			// Do nothing for literals, empty expression and identifiers
		}
		ast.OrExpr {
			context.check_statements(expression.stmts, fn_file)!
		}
		ast.InfixExpr {
			context.check_expression(expression.left, fn_file)!
			context.check_expression(expression.right, fn_file)!
			context.check_expression(expression.or_block, fn_file)!
		}
		ast.SelectorExpr {
			context.check_expression(expression.expr, fn_file)!
			context.check_expression(expression.or_block, fn_file)!
		}
		ast.CastExpr {
			context.check_expression(expression.arg, fn_file)!
			context.check_expression(expression.expr, fn_file)!
		}
		ast.PrefixExpr {
			context.check_expression(expression.right, fn_file)!
			context.check_expression(expression.or_block, fn_file)!
		}
		ast.PostfixExpr {
			context.check_expression(expression.expr, fn_file)!
		}
		ast.UnsafeExpr {
			context.check_expression(expression.expr, fn_file)!
		}
		ast.StructInit {
			for field_expr in expression.init_fields {
				context.check_expression(field_expr.expr, fn_file)!
			}
		}
		ast.CallExpr {
			call_expr := expression as ast.CallExpr
			context.check_expression(call_expr.or_block, fn_file)!
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

					// If the name was same, restore the original automata
					if receiver_name == identifier {
						context.reference_map[identifier] = automata
					}
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
		ast.ArrayInit {
			// Check the exprs, len_expr, cap_expr, and default_expr
			for expr in expression.exprs {
				context.check_expression(expr, fn_file)!
			}
			context.check_expression(expression.len_expr, fn_file)!
			context.check_expression(expression.cap_expr, fn_file)!
			context.check_expression(expression.default_expr, fn_file)!
		}
		ast.StringInterLiteral {
			// Check the exprs
			for expr in expression.exprs {
				context.check_expression(expr, fn_file)!
			}
		}
		ast.IfExpr {
			before_states := context.get_reference_states()
			for branch in expression.branches {
				// Check the condition
				mut copy_context := context.clone()!
				copy_context.check_expression(branch.cond, fn_file)!

				// Check the statements
				copy_context.check_statements(branch.stmts, fn_file)!
				after_states := copy_context.get_reference_states()
				prevent_regression(before_states, after_states)!
			}
		}
		ast.MatchExpr {
			// Check the condition
			context.check_expression(expression.cond, fn_file)!
			before_states := context.get_reference_states()

			// Check the branches
			for branch in expression.branches {
				mut copy_context := context.clone()!

				for expr in branch.exprs {
					copy_context.check_expression(expr, fn_file)!
				}
				copy_context.check_statements(branch.stmts, fn_file)!
				after_states := copy_context.get_reference_states()
				prevent_regression(before_states, after_states)!
			}
		}
		else {
			// Skip the unsupported expressions
			if expression.str().contains('unknown') {
				return
			}
			// unsupported expression type
			println('UNSUPPORTED: ${expression.type_name()}\t${expression}')
			// dump(expression.str().contains('unknown'))
		}
	}
}

fn (mut context TypestateContext) check_function(function ast.Fn) ! {
	statements, fn_file := context.get_statements_for(function)!
	context.check_statements(statements, fn_file)!
}
