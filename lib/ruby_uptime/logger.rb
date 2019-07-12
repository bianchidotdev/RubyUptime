<<<<<<< HEAD
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
=======
module RubyUptime
  module Logger
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
>>>>>>> c5eedbc04b6958363c5a58ba036cb595d18f5b7a
  end
end

# TODO: Add in the following
# caller_locations.first.path.split('/').last   # filename of caller
# caller_locations.first.label                  # method of caller
# caller_locations.first.lineno                 # line number of caller

def logger
<<<<<<< HEAD
  logger||=RubyUptime::Logger.new
=======
  binding.pry
  logger||=RubyUptime::Logger.init_logger("RubyUptime")
>>>>>>> c5eedbc04b6958363c5a58ba036cb595d18f5b7a
end
