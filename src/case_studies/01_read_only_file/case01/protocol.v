module main

import tpstv

pub enum FileStates {
	unready
	open
	reading
	closed
}

const protocol = tpstv.Protocol[FileStates]{
	name: 'Read-only File Protocol'
	types: ['read_only_file.ReadOnlyFile']
	rules: [
		tpstv.Rule[FileStates]{
			name: 'Open File'
			start: .unready
			end: .open
			stimulus: 'ReadOnlyFile.open'
		},
		tpstv.Rule[FileStates]{
			name: 'Read File'
			start: .open
			end: .reading
			stimulus: 'read'
		},
	]
}
