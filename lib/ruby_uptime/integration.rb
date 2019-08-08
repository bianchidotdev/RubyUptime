module RubyUptime
	class Integration
		attr_reader :integration_config

		def initialize(integration_key)
			@key = integration_key
			@valid = true
			defined_integrations = UserConfig.instance.integrations
			if defined_integrations.key?(integration_key)
				@integration_config = defined_integrations[integration_key]
				configure_integration
			else
				logger.warn("Could not find specified integration key #{integration_key} - skipping")
				@valid = false
			end
		rescue => e
      logger.warn("Error creating integration - #{e}")
      @error = "Error creating integration - #{e}"
      @valid = false
		end

		def trigger(check, sc_index, eval_id, success_status)
			errors = compile_errors(check, sc_index, eval_id)
			form_payload(check, eval_id, errors, success_status)
			binding.pry
		end

		private

		def compile_errors(check, sc_index, eval_id)
			check.requests[eval_id][:raw_results][sc_index]
		end

		def form_payload(check, eval_id, errors, success_status)
			type = success_status ? 'on_success' : 'on_failure'
			raw_results = check.requests[eval_id][:raw_results][sc_index]

			check_id = check.id
			check_name = check.name
			check_status = raw_results.dig(:status, :got)
			check_body = raw_results.dig(:body, :got)

			formatted_body = @body
			formatted_body.gsub!('#{check_id}', check_id)
			formatted_body.gsub!('#{check_name}', check_name)
			formatted_body.gsub!('#{check_status}', check_status)
			formatted_body.gsub!('#{check_body}', check_body)
			# formatted_body.gsub!('#{ssl_errors}', ssl_errors)

		end

		def configure_integration
			if @integration_config.key?('on_failure')
				failure_config = @integration_config['on_failure']
				@method = failure_config['method'] || 'POST'
				@endpoint = URI.parse(failure_config['endpoint'])
				# TODO: Fix json parse - doesn't seem to be working
				@body = JSON.parse(failure_config['body']) rescue failure_config['body'].to_s
				@headers = failure_config['headers']
			end
			if @integration_config.key?('on_success')
				success_config = @integration_config['on_success']
				@method = success_config['method'] || 'POST'
				@endpoint = URI.parse(success_config['endpoint'])
				@body = success_config['body']
				@headers = success_config['headers']
			end
		end
	end
end