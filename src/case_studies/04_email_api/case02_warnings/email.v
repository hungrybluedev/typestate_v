module main

import net.http
import os
import x.json2
import toml

const (
	user_agent            = 'Command-line Email Client (${os.user_os()})'
	from_name             = 'Subhomoy Haldar'
	from_email            = 'hello@hungrybluedev.tech'

	default_toml_location = @VMODROOT + '/src/case_studies/04_email_api/config.toml'
)

pub struct Person {
	email string
	name  string
}

pub struct Mail {
	sender       Person
	to           []Person
	subject      string
	text_content string   [json: 'textContent']
}

pub struct Service {
	key  string
	host string
mut:
	sender Person
}

pub fn Service.from_config() !Service {
	if !os.exists(default_toml_location) {
		return error('Config file not found at ${default_toml_location}')
	}

	config_file := toml.parse_file(default_toml_location) or {
		return error('Error while parsing config file:\n${err}')
	}

	api_params := config_file.value_opt('api') or {
		return error('Config file does not contain mail service API parameters.')
	}

	key := (api_params.value_opt('key') or { return error('Config file does not contain API key.') }).string()

	host := (api_params.value_opt('host') or {
		return error('Config file does not contain API host endpoint.')
	}).string()

	return Service{
		key: key
		host: host
	}
}

pub fn (mut service Service) add_sender(sender Person) ! {
	clean_email := sender.email.trim_space()
	if clean_email == '' {
		return error('Sender email address cannot be empty.')
	}

	clean_name := sender.name.trim_space()
	if clean_name == '' {
		return error('Sender name cannot be empty.')
	}

	service.sender = Person{
		email: clean_email
		name: clean_name
	}
}

pub fn (service Service) send_mail(mail Mail) ! {
	data_json := json2.encode[Mail](Mail{
		...mail
		sender: service.sender
	})

	request := http.Request{
		method: .post
		header: http.new_custom_header_from_map({
			http.CommonHeader.accept.str():       'application/json'
			http.CommonHeader.content_type.str(): 'application/json'
			http.CommonHeader.user_agent.str():   user_agent
			'api-key':                            service.key
		})!
		url: service.host
		user_agent: user_agent
		data: data_json
	}

	response := request.do() or {
		return error('Network error occurred while sending email:\n${err}')
	}
	if response.status_code / 100 != 2 {
		println(response)
		return error('\n\nError while trying to send email.')
	} else {
		println('Email sent successfully.\n')
	}
}

fn main() {
	println('Command-line Email Client')
	println('-------------------------\n\n')

	println('Loading config file...')
	mut service := Service.from_config()!
	println('Config file loaded successfully.\n')

	println('Adding sender details...')
	service.add_sender(Person{
		email: from_email
		name: from_name
	})!
	println('Sender details added successfully.\n')

	println('Type exit to exit the program.\n')

	for (true) {
		to_email := (os.input_opt('Enter recipient email address: ') or {
			println('\nCould not obtain recipient email address.\nTrying again...')
			continue
		}).trim_space()
		reply_to := 'none'

		if to_email.to_lower() == 'exit' {
			println('\nExiting...')
			break
		}

		to_name := (os.input_opt('Enter recipient name: ') or {
			println('\nCould not obtain recipient name.\nTrying again...')
			continue
		}).trim_space()

		if to_name.to_lower() == 'exit' {
			println('\nExiting...')
			break
		}

		subject := (os.input_opt('Enter email subject: ') or {
			println('\nCould not obtain email subject.\nTrying again...')
			continue
		}).trim_space()

		if subject.to_lower() == 'exit' {
			println('\nExiting...')
			break
		}

		content := (os.input_opt('Enter email content\n(in one line, use "\\n" for new line): ') or {
			println('\nCould not obtain email content.\nTrying again...')
			continue
		}).trim_space()

		if content.to_lower() == 'exit' {
			println('\nExiting...')
			break
		}

		content_lines := content.split('\\n').join_lines()

		mail := Mail{
			to: [
				Person{
					email: to_email
					name: to_name
				},
			]
			subject: subject
			text_content: content_lines
		}

		println('\nSending email...')
		service.send_mail(mail) or {
			println('\nError while sending email:\n${err}')
			continue
		}
	}
}
