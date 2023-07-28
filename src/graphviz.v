module main

import cli
import os

fn visualize(command cli.Command) ! {
	mut context := first_steps(command)!

	dot_string := context.discovered_protocol.get_dot()

	println('Generated DOT string:\n')
	println(dot_string)

	input := os.join_path(context.directory, 'fsm.dot')
	output := os.join_path(context.directory, 'fsm.png')

	if os.exists(input) {
		os.rm(input)!
	}
	if os.exists(output) {
		os.rm(output)!
	}

	os.write_file(input, dot_string)!

	result := os.execute('dot -Tpng -Gdpi=300 -o ${output} ${input}')
	if result.exit_code != 0 {
		return error('Could not generate FSM visualization. Make sure you have Graphviz installed.\nDetails: ${result.output}')
	}
}
