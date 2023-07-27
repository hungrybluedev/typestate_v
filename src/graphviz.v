module main

import cli

fn visualize(command cli.Command) ! {
	mut context := first_steps(command)!

	println(context.discovered_protocol.get_dot())
}
