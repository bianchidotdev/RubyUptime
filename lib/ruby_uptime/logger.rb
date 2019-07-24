module RubyUptime
  class Logger
    def self.init_logger(logger_name, log_file="#{APP_ENV}.log")
      SemanticLogger.default_level = :trace
      SemanticLogger.add_appender(
        file_name: "#{PROJECT_ROOT}/log/#{log_file}", level: :info, formatter: :json
      )
      SemanticLogger.add_appender(
        io: $stdout, level: :debug, formatter: :color
      )
      logger = SemanticLogger[logger_name]
  
      logger
    end

    def self.logger
      @logger ||= self.init_logger("RubyUptime")
    end
  end
end

# TODO: Add in the following
# caller_locations.first.path.split('/').last   # filename of caller
# caller_locations.first.label                  # method of caller
# caller_locations.first.lineno                 # line number of caller

def logger
  @logger ||= RubyUptime::Logger.logger
end
