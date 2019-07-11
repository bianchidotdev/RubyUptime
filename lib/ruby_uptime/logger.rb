class RubyUptime::Logger
  def initialize log_file="#{ENV}.log"
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
end    
def logger(logger_name)
      logger ||=begin
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
    end
  end
end

def logger
  logger||=RubyUptime::Logger.new AppConfig.logger.log_file
end
