module main

import v.ast
import v.builder
import v.errors
import v.pref as preferences
import v.parser
import os
import strings

struct TypestateState {
	index int
	name  string
}

struct TypestateRule {
	name        string
	description string

	start TypestateState
	end   TypestateState

	stimulus string
}

struct TypestateProtocol {
	full_type   ast.Type
	name        string
	description string
	states      []TypestateState
	rules       []TypestateRule
}

fn (protocol TypestateProtocol) has_state(state TypestateState) bool {
	for protocol_state in protocol.states {
		if protocol_state.name == state.name {
			return true
		}
	}
	return false
}

fn (protocol TypestateProtocol) get_dot() string {
	mut output := strings.new_builder(1024)

	mut graph_name := []u8{}

	for ch in protocol.name {
		if ch.is_alnum() {
			graph_name << ch
		}
	}

	output.write_string('digraph ${graph_name.bytestr()} {\n')
	output.write_string('\tlabel="${protocol.name}";\n')
	output.write_string('\tfontname="Helvetica,Arial,sans-serif";\n')
	output.write_string('\tnode [fontname="Helvetica,Arial,sans-serif"];\n')
	output.write_string('\tedge [fontname="Helvetica,Arial,sans-serif"];\n')
	output.write_string('\trankdir=LR;\n\tnodesep=1.5;\n')
	output.write_string('\tnode [shape=circle,size=5];\n')

	for rule in protocol.rules {
		transition_name := rule.stimulus.after_char(`.`)
		output.write_string('	${rule.start.name} -> ${rule.end.name} [label="${transition_name}"];\n')
	}

	output.write_string('}\n')

	return output.str()
}

[heap]
struct TypestateContext {
	directory string
mut:
	builder      builder.Builder      // For parsing and checking
	path_ast_map map[string]&ast.File // For easy lookup of ASTs

	discovered_protocol TypestateProtocol  // The protocol that was discovered
	target_type         &ast.TypeSymbol    = unsafe { nil } // The type that is targeted
	original_automata   &TypestateAutomata = unsafe { nil } // The automata that was generated from the protocol
	just_name           string // The simplified name of the target type
	// All references have independent automata
	reference_map map[string]&TypestateAutomata = map[string]&TypestateAutomata{}
	// Avoid revisiting the same functions
	visited_functions map[string]bool = map[string]bool{}
	// Unsupported expressions and statements encountered
	unsupported_count int
}

fn TypestateContext.generate_context(directory string) !TypestateContext {
	mut context := TypestateContext{
		directory: directory
		builder: builder.new_builder(&preferences.Preferences{
			...preferences.new_preferences()
			path: directory
			check_only: true
		})
	}

	// os.chdir(@VEXEROOT)!

	// module builtin is always implicitly imported
	// mut source_files := context.builder.get_builtin_files()
	mut source_files := context.builder.v_files_from_dir(os.join_path(@VEXEROOT, 'vlib',
		'builtin'))

	// All "user" files are obtained from the directory set in the preferences
	source_files << context.builder.get_user_files()
	// source_files << context.builder.v_files_from_dir(os.real_path(directory))

	// Set the module lookup paths for recursive import resolution
	// context.builder.module_search_paths << @VEXEROOT
	context.builder.set_module_lookup_paths()

	// println('Parsing all provided source files.')

	// Parse all initial files
	context.builder.parsed_files = parser.parse_files(source_files, context.builder.table,
		context.builder.pref)

	// println('Parsing imports.')

	// Parse all imports
	context.builder.parse_imports()

	// dump(context.builder.parsed_files.map(it.path))

	// Add the ASTs in a map for easy lookup
	for ast in context.builder.parsed_files {
		context.path_ast_map[os.real_path(ast.path)] = ast
	}

	return context
}

fn (mut context TypestateContext) precheck() ! {
	// println('Transforming generic constructs.')
	context.builder.table.generic_insts_to_concrete()

	// println('Checking files.')
	context.builder.checker.check_files(context.builder.parsed_files)

	if context.builder.checker.errors.len > 0 {
		return error('Standard checking failed with the following errors:\n${serialise_errors(context.builder.checker.errors)}')
	}

	if context.builder.checker.warnings.len > 0 {
		return error('Standard checking produced the following warnings:\n${serialise_warnings(context.builder.checker.warnings)}')
	}

	// println('Standard checking passed')
}

fn (context TypestateContext) get_reference_states() map[string]TypestateState {
	mut states := map[string]TypestateState{}

	for ref, automata in context.reference_map {
		states[ref] = automata.current
	}

	return states
}

fn (mut context TypestateContext) set_reference_states(states map[string]TypestateState) ! {
	for ref, state in states {
		mut automata := context.reference_map[ref] or {
			return error('Reference ${ref} does not exist')
		}
		automata.current = state
	}
}

fn serialise_errors(errs []errors.Error) string {
	mut output := strings.new_builder(errs.len * 128)

	for err in errs {
		output.write_string('${err.file_path}:${err.pos.line_nr + 1}: ${err.message}\n')
	}

	return output.str()
}

fn serialise_warnings(warnings []errors.Warning) string {
	mut output := strings.new_builder(warnings.len * 128)

	for warning in warnings {
		output.write_string('${warning.file_path}:${warning.pos.line_nr + 1}: ${warning.message}\n')
	}

	return output.str()
}

fn serialise_state_error(err IError, file string, line int) string {
	short_file := file.all_after(@VMODROOT + os.path_separator)
	return '${short_file}:${line + 1}: ${err.msg()}\n'
}

fn (context TypestateContext) get_statements_for(function ast.Fn) !([]ast.Stmt, string) {
	// Find the ast in the parsed files
	target_file := os.real_path(function.file)
	target_ast := context.path_ast_map[target_file] or {
		return error('Unable to find file ${target_file}.')
	}

	// Find the function in the AST
	for statement in target_ast.stmts {
		if statement is ast.FnDecl && statement.name == function.name {
			mut original_statements := statement.stmts.clone()

			for ds in statement.defer_stmts {
				original_statements << ds.stmts
			}

			return original_statements, target_file
		}
	}

	return error('Unable to find function ${function.name} in file ${target_file}.')
}

fn (mut context TypestateContext) clone() !TypestateContext {
	return TypestateContext{
		directory: context.directory
		builder: context.builder
		path_ast_map: context.path_ast_map.clone()
		discovered_protocol: context.discovered_protocol
		target_type: context.target_type
		original_automata: context.original_automata.clone_ref()
		just_name: context.just_name
		reference_map: context.reference_map.clone()
		visited_functions: context.visited_functions.clone()
	}
}

fn extract_rule(fields []ast.StructInitField) !TypestateRule {
	mut rule_name := 'Not found'
	mut stimulus := 'Not found'

	mut start := TypestateState{}
	mut end := TypestateState{}

	for field in fields {
		if field.name == 'name' {
			string_val := field.expr as ast.StringLiteral
			rule_name = string_val.val
		}
		if field.name == 'stimulus' {
			string_val := field.expr as ast.StringLiteral
			stimulus = string_val.val
		}
		if field.name == 'start' {
			enum_val := field.expr as ast.EnumVal
			start = TypestateState{
				name: enum_val.val
			}
		}
		if field.name == 'end' {
			enum_val := field.expr as ast.EnumVal
			end = TypestateState{
				name: enum_val.val
			}
		}
	}

	return TypestateRule{
		name: rule_name
		stimulus: stimulus
		start: start
		end: end
	}
}

fn extract_all_rules(rules ast.Expr) ![]TypestateRule {
	if rules is ast.ArrayInit {
		mut rule_buffer := []TypestateRule{}
		for rule in rules.exprs {
			rule_decl := rule as ast.StructInit
			rule_buffer << extract_rule(rule_decl.init_fields)!
		}
		return rule_buffer
	} else {
		return error('Expected an array of rules.')
	}
}

fn extract_protocol(protocol_statements []ast.Stmt) !TypestateProtocol {
	// For the states
	mut already_found_protocol_states := false
	mut discovered_states := []TypestateState{}

	// For the rules
	mut already_found_protocol_rules := false
	mut discovered_rules := []TypestateRule{}

	mut protocol_name := 'Not found'
	mut protocol_description := 'Not found'

	mut protocol_type := -1

	for statement in protocol_statements {
		if statement is ast.EnumDecl {
			if already_found_protocol_states {
				return error('Found more than one protocol in the protocol file.')
			}

			// Extract all the enum values
			for index, state in statement.fields {
				discovered_states << TypestateState{
					name: state.name
					index: index
				}
			}

			//
			already_found_protocol_states = true
		}

		if statement is ast.ConstDecl {
			// Find the protocol constant
			for const_field in statement.fields {
				if const_field.name.ends_with('protocol') && const_field.expr is ast.StructInit {
					// Show the types related to the protocol
					protocol_type = const_field.typ

					init_fields := const_field.expr.init_fields
					for init_field in init_fields {
						match init_field.name {
							'rules' {
								if already_found_protocol_rules {
									return error('Found more than one protocol in the protocol file.')
								}
								discovered_rules << extract_all_rules(init_field.expr)!

								already_found_protocol_rules = true
							}
							'name' {
								protocol_name = (init_field.expr as ast.StringLiteral).val
							}
							'description' {
								protocol_description = (init_field.expr as ast.StringLiteral).val
							}
							else {
								return error('Unknown field in protocol constant.')
							}
						}
					}
				}
			}
		}
	}
	return TypestateProtocol{
		full_type: protocol_type
		name: protocol_name
		description: protocol_description
		states: discovered_states
		rules: discovered_rules
	}
}

struct TypestateTransition {
	stimulus string
	start    TypestateState
	end      TypestateState
}

[heap]
struct TypestateAutomata {
	states        []TypestateState
	initial_state TypestateState
	transitions   map[string]TypestateTransition
mut:
	ref string
	current    TypestateState
	call_chain []string = ['new instance']
}

fn TypestateAutomata.build(protocol TypestateProtocol) !TypestateAutomata {
	states := protocol.states
	rules := protocol.rules

	mut transitions := map[string]TypestateTransition{}

	for rule in rules {
		key := '${rule.start.name} + ${rule.stimulus}'
		if key in transitions {
			return error('Found duplicate transition: ${key}')
		}
		transitions[key] = TypestateTransition{
			stimulus: rule.stimulus
			start: rule.start
			end: rule.end
		}
	}

	return TypestateAutomata{
		states: states
		initial_state: states[0]
		transitions: transitions
		current: states[0]
	}
}

fn (automata TypestateAutomata) clone_ref() &TypestateAutomata {
	states_copy := automata.states.clone()
	return &TypestateAutomata{
		states: states_copy
		initial_state: states_copy[0]
		transitions: automata.transitions.clone()
		current: states_copy[0]
	}
}

fn (mut automata TypestateAutomata) accept(function string) ! {
	// Check if it is a static function
	actual_name := if function.contains('__static__') {
		function.all_before('.') + '.static.' + function.all_after('__static__')
	} else {
		function
	}

	automata.call_chain << actual_name

	key := '${automata.current.name} + ${actual_name}'
	if automata.current != automata.transitions[key].start {
		critical_path := automata.call_chain.join(' -> ')
		return error('Current state for ${automata.ref} is ${automata.current.name}. Transition "${key}" not accepted. Path taken: ${critical_path}')
	}
	if key !in automata.transitions {
		return error('Invalid transition: ${key}')
	}

	transition := automata.transitions[key]
	automata.current = transition.end
}
