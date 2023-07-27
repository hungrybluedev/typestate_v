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
		os.join_path('01_read_only_file', 'case04_invalid'),
		// Speaker
		os.join_path('02_speaker', 'case01_errors'),
		os.join_path('02_speaker', 'case02_warnings'),
		os.join_path('02_speaker', 'case03_normal'),
		os.join_path('02_speaker', 'case04_invalid'),
		// Histogram
		os.join_path('03_histogram', 'case01_errors'),
		os.join_path('03_histogram', 'case02_warnings'),
		os.join_path('03_histogram', 'case03_normal'),
		os.join_path('03_histogram', 'case04_invalid'),
		// Email API
		os.join_path('04_email_api', 'case01_errors'),
		os.join_path('04_email_api', 'case02_warnings'),
		os.join_path('04_email_api', 'case03_normal'),
		os.join_path('04_email_api', 'case04_invalid'),
		// Fibonacci
		os.join_path('05_fibonacci', 'case01_errors'),
		os.join_path('05_fibonacci', 'case02_warnings'),
		os.join_path('05_fibonacci', 'case03_normal'),
		os.join_path('05_fibonacci', 'case04_invalid'),
	]
)

fn run_for_case_studies(command cli.Command) ! {
	mut count := 0
	working_dir := os.getwd() + os.path_separator

	for directory in case_study_directories {
		path := os.join_path(os.real_path(case_study_location), directory)

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
				if line.starts_with('\tFile: ') {
					lines[index] = '\tFile: ${line.all_after(working_dir)}'
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
