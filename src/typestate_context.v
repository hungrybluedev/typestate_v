module main

import v.pref as preferences
import v.builder
import v.parser
import v.errors
import strings

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
