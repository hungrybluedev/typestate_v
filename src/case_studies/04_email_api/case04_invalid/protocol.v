module main

import tpstv

pub enum ServiceStates {
	uninitialized
	configured
	sender_added
}

const protocol = tpstv.Protocol[Service, ServiceStates]{
	name: 'Email Service Protocol'
	rules: [
		tpstv.Rule[ServiceStates]{
			name: 'Create a service from a configuration file.'
			description: 'The configuration file contains the API key and the endpoint.'
			start: .uninitialized
			end: .configured
			stimulus: 'Service.static.from_config'
		},
		tpstv.Rule[ServiceStates]{
			name: 'Add a sender to the service.'
			description: 'The Email service sends emails on behalf of a validated sender.'
			start: .configured
			end: .sender_added
			stimulus: 'Service.add_sender'
		},
		tpstv.Rule[ServiceStates]{
			name: 'Send an email from the service.'
			start: .sender_added
			end: .sender_added
			stimulus: 'Service.send_mail'
		},
	]
}
