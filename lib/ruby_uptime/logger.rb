class RubyUptime::Logger
  def initialize log_file="#{APP_ENV}.log"
    SemanticLogger.default_level = :trace
    SemanticLogger.add_appender(
      file_name: "#{AppConfig.paths.log_dir}/#{log_file}", level: :info, formatter: :json
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

def logger
  logger||=RubyUptime::Logger.new
end
