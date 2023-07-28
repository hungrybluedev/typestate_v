module main

import tpstv

pub enum SpeakerStates {
	off
	on
	low
	high
}

const protocol = tpstv.Protocol[Speaker, SpeakerStates]{
	name: 'Speaker protocol'
	rules: [
		tpstv.Rule[SpeakerStates]{
			name: 'Turn on speaker'
			start: .off
			end: .on
			stimulus: 'Speaker.turn_on'
		},
		// All the different ways to turn off the speaker
		tpstv.Rule[SpeakerStates]{
			name: 'Turn off speaker from on'
			start: .on
			end: .off
			stimulus: 'Speaker.turn_off'
		},
		tpstv.Rule[SpeakerStates]{
			name: 'Turn off speaker from low'
			start: .low
			end: .off
			stimulus: 'Speaker.turn_off'
		},
		tpstv.Rule[SpeakerStates]{
			name: 'Turn off speaker from high'
			start: .high
			end: .off
			stimulus: 'Speaker.turn_off'
		},
		// All the different ways to turn the speaker low
		tpstv.Rule[SpeakerStates]{
			name: 'Turn speaker low from on'
			start: .on
			end: .low
			stimulus: 'Speaker.turn_low'
		},
		tpstv.Rule[SpeakerStates]{
			name: 'Turn speaker low from high'
			start: .high
			end: .low
			stimulus: 'Speaker.turn_low'
		},
		// All the different ways to turn the speaker high
		tpstv.Rule[SpeakerStates]{
			name: 'Turn speaker high from on'
			start: .on
			end: .high
			stimulus: 'Speaker.turn_high'
		},
		tpstv.Rule[SpeakerStates]{
			name: 'Turn speaker high from low'
			start: .low
			end: .high
			stimulus: 'Speaker.turn_high'
		},
	]
}
