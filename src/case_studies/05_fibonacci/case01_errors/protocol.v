module main

import tpstv

pub enum FibStates {
	new
	prepared
	running
}

const protocol = tpstv.Protocol[Fibonacci, FibStates]{
	name: 'Memoised Fibonacci Protocol'
	rules: [
		// We can only prepare the cache if we're in the new state
		tpstv.Rule[FibStates]{
			name: 'Prepare and populate the cache'
			start: .new
			end: .prepared
			stimulus: 'Fibonacci.prepare'
		},
		// We can start extracting numbers from the cache regardless of state
		tpstv.Rule[FibStates]{
			name: 'Generate nth number in the sequence when uncached'
			start: .new
			end: .running
			stimulus: 'Fibonacci.nth'
		},
		tpstv.Rule[FibStates]{
			name: 'Generate nth number in the sequence when cached'
			start: .prepared
			end: .running
			stimulus: 'Fibonacci.nth'
		},
	]
}
