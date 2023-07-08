module main

import os
import cli

const (
	case_study_location    = os.join_path('src', 'case_studies')
	case_study_directories = [
		// Read-only file
		os.join_path('01_read_only_file', 'case01_errors'),
		os.join_path('01_read_only_file', 'case02_warnings'),
		os.join_path('01_read_only_file', 'case03_normal'),
		// os.join_path('01_read_only_file', 'case04_invalid'),
		// Speaker
		os.join_path('02_speaker', 'case01_errors'),
		// RNG
	]
)

fn run_for_case_studies(command cli.Command) ! {
	mut count := 0
	for directory in case_study_directories {
		path := os.join_path(case_study_location, directory)

		println('\nRunning case study: typestate_v ${path}\n')

		expected_error_path := os.join_path(path, 'expected_error.txt')
		expecting_error := os.exists(expected_error_path)
		mut found_error := false

		start(cli.Command{ args: [path] }) or {
			// An error occurred. Check to see if it was expected.
			expected_error := os.read_file(expected_error_path)!
			actual_error := err.str()

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
