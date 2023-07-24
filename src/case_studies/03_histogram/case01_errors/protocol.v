module main

import tpstv

pub enum HistogramStates {
	unready
	ready
	collecting
}

const protocol = tpstv.Protocol[Histogram, HistogramStates]{
	name: 'Histogram Protocol'
	rules: [
		tpstv.Rule[HistogramStates]{
			name: 'Create a histogram from config.'
			start: .unready
			end: .ready
			stimulus: 'Histogram.static.with_bins'
		},
		// We must add at least one point to the histogram.
		tpstv.Rule[HistogramStates]{
			name: 'Collect first data point for the histogram.'
			start: .ready
			end: .collecting
			stimulus: 'Histogram.add'
		},
		// We can add as many points as we want to the histogram.
		tpstv.Rule[HistogramStates]{
			name: 'Collect more data points for the histogram.'
			start: .collecting
			end: .collecting
			stimulus: 'Histogram.add'
		},
		// We must have at least one point to be able to print the histogram.
		tpstv.Rule[HistogramStates]{
			name: 'Print the histogram.'
			start: .collecting
			end: .collecting
			stimulus: 'Histogram.print'
		},
	]
}
