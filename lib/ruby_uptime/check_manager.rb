module RubyUptime
  module CheckManager
    def create_checks(check_options)
      checks = []
      check_options.each do |check_option|
        check = Check.new check_option
        checks << check if check.valid?
      end
      checks
    end

    def eval_check(check, logger)
      time = Time.now.utc.to_f

      conn = Faraday.new do |c|
        c.adapter Faraday.default_adapter
      end

      if check.next_time < time
        check.last_time = time
        check.set_next_time
        begin
          resp, duration = check.eval(conn)
        rescue StandardError => e
          logger.warn("Error checking host #{check.uri} - #{e.class}: #{e.message}")
        end
        request = {
          :resp => resp,
          :duration => duration,
        }
        check.add_request(time, request)

        check.successful? ? check.on_success(time) : check.on_failure(time)
        check.remove_request(time)
      end
    end
  end
end