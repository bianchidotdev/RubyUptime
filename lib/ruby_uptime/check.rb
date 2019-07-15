require 'semantic_logger'
require 'faraday'

class CheckCreationError < StandardError; end

class RubyUptime::Check

  include SemanticLogger::Loggable
  attr_accessor :last_time
  attr_reader :next_time, :name, :uri, :reqs, :error

  def self.log_header
    logger.info(
      "Check Time - Check Name - Check Status - Check Body - Next Check Due Time - \
Duration"
  )
  end

  def initialize(name)
    @name = name
    user_config = UserConfig.instance
    raise CheckCreationError("could not find config for check #{name}") unless user_config[name]
    @user_defined_config = user_config[name]
    @uri = gen_uri
    @next_time = Time.now.utc.to_f
    @frequency = nil
    @reqs = {}
  rescue StandardError => e
    logger.warn("Error creating check - #{e}")
    @error = e
    @valid = false
  end

  # def name=(name)
  #   raise ArgumentError.new('No name provided') unless name

  #   @name = name
  # end

  # def host=(host)
  #   raise ArgumentError.new('No host provided') unless host

  #   @host = host
  # end

  def valid?
    @valid != false
  end

  def eval(conn)
    start_time = Time.now.utc.to_f
    resp = conn.get @uri
    end_time = Time.now.utc.to_f
    duration = end_time - start_time
    [resp, duration]
  end

  def set_next_time
    @next_time = @next_time + @frequency
  end

  def add_request(time, request)
    @reqs[time] = request
  end

  def remove_request(time)
    @reqs.delete(time)
  end

  def successful?
    return true
  end

  def on_success(time)
    name = self.name
    last_time = Time.at(self.last_time).utc
    next_time = Time.at(self.next_time).utc
    response = self.reqs[time][:resp]
    status = response.status
    body = response.body
    duration = self.reqs[time][:duration]
    logger.info(
      "#{last_time} - #{name} - #{status} - #{body} - #{next_time} - \
#{duration.round(3)}s"
    )
  end

  def on_failure(time)
  end

  private

  def gen_uri
    host = @user_defined_config['host']
    raise ArgumentError('No host provided') unless host

    protocol = @user_defined_config['protocol'] || AppConfig.check_defaults.protocol
    endpoint = @user_defined_config['endpoint'] || AppConfig.check_defaults.endpoint
    Faraday::Utils::URI("#{protocol}://#{host}#{endpoint}")
  end
end
  