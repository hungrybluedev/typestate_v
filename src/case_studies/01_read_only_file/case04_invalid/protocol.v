module main

import tpstv

pub enum FileStates {
	unready
	open
	reading
	closed
}

const protocol = tpstv.Protocol[ReadOnlyFile, FileStates]{
	name: 'Read-only File Protocol'
	rules: [
		tpstv.Rule[FileStates]{
			name: 'Open File'
			start: .unready
			end: .open
			stimulus: 'ReadOnlyFile.static.open'
		},
		tpstv.Rule[FileStates]{
			name: 'Read File'
			start: .open
			end: .reading
			stimulus: 'ReadOnlyFile.read_line'
		},
		// All the ways to close a file
		tpstv.Rule[FileStates]{
			name: 'Close File from reading'
			start: .reading
			end: .closed
			stimulus: 'ReadOnlyFile.close'
		},
		tpstv.Rule[FileStates]{
			name: 'Close File from open'
			start: .open
			end: .closed
			stimulus: 'ReadOnlyFile.close'
		},
		tpstv.Rule[FileStates]{
			name: 'Close File from unready'
			start: .unready
			end: .closed
			stimulus: 'ReadOnlyFile.close'
		},
		// Allow reading once reading has started
		tpstv.Rule[FileStates]{
			name: 'Read File from reading'
			start: .reading
			end: .reading
			stimulus: 'ReadOnlyFile.read_line'
		},
	]
}
