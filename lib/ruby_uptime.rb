require 'pry'

module RubyUptime
  NAME = "RubyUptime"
  LICENSE = "See LICENSE for licensing details."

  DEFAULTS = {
    check_frequency: 10,
    check_protocol: 'https',
    check_endpoint: '/testall',
    require: ".",
    environment: nil,
    timeout: 10,
  }

  require_relative 'ruby_uptime/check'

  def init_logger(logger_name)
    SemanticLogger.default_level = :trace
    SemanticLogger.add_appender(
      file_name: '../development.log', level: :info, formatter: :json
    )
    SemanticLogger.add_appender(
      io: $stdout, level: :debug, formatter: :color
    )

    logger = SemanticLogger[logger_name]

    logger
  end

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