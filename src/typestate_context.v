module main

import v.ast
import v.builder
import v.errors
import v.pref as preferences
import v.parser
import strings

struct TypestateState {
	name string
}

struct TypestateRule {
	name        string
	description string

	start TypestateState
	end   TypestateState

	stimulus string
}

struct TypestateProtocol {
	name        string
	description string
	states      []TypestateState
	rules       []TypestateRule
}

[heap]
struct TypestateContext {
	directory string
mut:
	builder builder.Builder
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

	// module builtin is always implicitly imported
	mut source_files := context.builder.get_builtin_files()

	// All "user" files are obtained from the directory set in the preferences
	source_files << context.builder.get_user_files()

	// Set the module lookup paths for recursive import resolution
	context.builder.set_module_lookup_paths()

	println('Parsing all provided source files.')

	// Parse all initial files
	context.builder.parsed_files = parser.parse_files(source_files, context.builder.table,
		context.builder.pref)

	println('Parsing imports.')

	// Parse all imports
	context.builder.parse_imports()

	return context
}

fn (mut context TypestateContext) precheck() ! {
	println('Transforming generic constructs.')
	context.builder.table.generic_insts_to_concrete()

	println('Checking files.')
	context.builder.checker.check_files(context.builder.parsed_files)

	if context.builder.checker.errors.len > 0 {
		return error('Standard checking failed with the following errors:\n${serialise_errors(context.builder.checker.errors)}')
	}

	if context.builder.checker.warnings.len > 0 {
		return error('Standard checking produced the following warnings:\n${serialise_warnings(context.builder.checker.warnings)}')
	}

	println('Standard checking passed')
}

fn serialise_errors(errs []errors.Error) string {
	mut output := strings.new_builder(errs.len * 128)

	for index, err in errs {
		output.write_string('${index + 1}: ${err.message}\n')
		output.write_string('	File: ${err.file_path}\n')
		output.write_string('	Line: ${err.pos.line_nr + 1}\n')
	}

	return output.str()
}

fn serialise_warnings(warnings []errors.Warning) string {
	mut output := strings.new_builder(warnings.len * 128)

	for index, warning in warnings {
		output.write_string('${index + 1}: ${warning.message}\n')
		output.write_string('	File: ${warning.file_path}\n')
		output.write_string('	Line: ${warning.pos.line_nr + 1}\n')
	}

	return output.str()
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

	for statement in protocol_statements {
		if statement is ast.EnumDecl {
			if already_found_protocol_states {
				return error('Found more than one protocol in the protocol file.')
			}

			// Extract all the enum values
			for state in statement.fields {
				discovered_states << TypestateState{
					name: state.name
				}
			}

			//
			already_found_protocol_states = true
		}
		if statement is ast.ConstDecl {
			// Find the protocol constant
			for const_field in statement.fields {
				if const_field.name.ends_with('protocol') && const_field.expr is ast.StructInit {
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
		name: protocol_name
		description: protocol_description
		states: discovered_states
		rules: discovered_rules
	}
}
