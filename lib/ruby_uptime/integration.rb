module RubyUptime
	class Integration
		attr_reader :integration_config

		def initialize(integration_key)
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

		private

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