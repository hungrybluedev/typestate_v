module main

import os

pub struct ReadOnlyFile {
	os.File
}

pub fn ReadOnlyFile.open(path string) !ReadOnlyFile {
	file := os.open(path)!
	return ReadOnlyFile{file}
}

pub fn (mut file ReadOnlyFile) read_line() !string {
	mut line_buffer := []u8{len: 256}

	count := file.read_bytes_into_newline(mut line_buffer) or {
		return error('An error occurred while reading from file: ' + err.str())
	}

	return if count == 0 {
		error('No content left to read.')
	} else {
		line_buffer.bytestr()
	}
}

fn (f ReadOnlyFile) close() {
	f.close()
}

fn main() {
	mut sample_file := ReadOnlyFile.open('data/sample.txt')!

	// Don't close the file here
	// sample_file.close()

	for {
		line := sample_file.read_line() or { break }
		println('Line read: ${line}')
	}

	sample_file.close()
}
