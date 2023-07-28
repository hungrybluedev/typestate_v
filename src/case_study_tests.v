module main

import os
import cli

const (
	case_study_location    = os.join_path('src', 'case_studies')
	case_study_directories = get_all_sub_cases(case_study_location) or {
		panic('Could not obtain all the test cases.')
	}
)

fn get_all_sub_cases(case_study_location string) ![]string {
	mut dirs := []string{}

	for example in os.ls(case_study_location)! {
		rel_path := os.join_path(case_study_location, example)
		if os.is_dir(rel_path) {
			// Now list all the subdirectories.
			dirs << os.ls(rel_path)!
				.map(os.join_path(rel_path, it))
				.filter(os.is_dir(it))
		}
	}

	return dirs
}

fn run_for_case_studies(command cli.Command) ! {
	mut count := 0
	working_dir := os.getwd() + os.path_separator

	for directory in case_study_directories {
		path := os.real_path(directory)

		println('\nRunning case study: typestate_v ${path}\n')

		expected_error_path := os.join_path(path, 'expected_error.txt')
		expecting_error := os.exists(expected_error_path)
		mut found_error := false

		start(cli.Command{ args: [path] }) or {
			// An error occurred. Check to see if it was expected.
			// dump(err)

			// To make the errors cross-platform, replace all forward slashes with the OS-specific separator.
			expected_error := os.read_file(expected_error_path)!.replace('/', os.path_separator)

			actual_error_raw := err.str()
			// Normalise to get relative paths.
			mut lines := actual_error_raw.split_into_lines()
			for index, line in lines {
				if line.contains(':') {
					lines[index] = '${line.all_after(working_dir)}'
				}
			}
			actual_error := lines.join_lines() + '\n'

			if expected_error != actual_error {
				return error('Expected error:\n"${expected_error}"\n\nActual error:\n"${actual_error}"\n')
			}

			found_error = true
		}

		if expecting_error && !found_error {
			return error('Expected an error but none occurred.')
		}
		count++
	}

	println('\nRan ${count} case studies successfully.')
}
