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
		tpstv.Rule[FileStates]{
			name: 'Close File'
			start: .reading
			end: .closed
			stimulus: 'ReadOnlyFile.close'
		},
	]
}
