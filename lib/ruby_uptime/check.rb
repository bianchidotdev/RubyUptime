require 'semantic_logger'
require 'http'

class CheckCreationError < StandardError; end

class RubyUptime::Check

  include SemanticLogger::Loggable
  attr_accessor :last_time
  attr_reader :next_time, :name, :uri, :requests, :error, :frequency, :headers

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
    configure_check
  rescue StandardError => e
    logger.warn("Error creating check - #{e}")
    @error = "Error creating check - #{e}"
    @valid = false
  end

  def valid?
    @valid != false
  end

  def eval
    http = HTTP
      .headers(@headers)
      .follow(max_hops: 5)
    start_time = Time.now.utc.to_f
    resp = http.get @uri
    end_time = Time.now.utc.to_f
    duration = end_time - start_time
    [resp, duration]
  end

  def set_next_time
    @next_time = @next_time + @frequency
  end

  def add_request(time, request)
    @requests[time] = request
  end

  def remove_request(time)
    @requests.delete(time)
  end

  def successful?
    return true
  end

  def on_success(time)
    name = self.name
    last_time = Time.at(self.last_time).utc
    next_time = Time.at(self.next_time).utc
    response = self.requests[time][:resp]
    status = response.status
    body = response.body
    duration = self.requests[time][:duration]
    logger.info(
      "#{last_time} - #{name} - #{status} - #{body} - #{next_time} - \
#{duration.round(3)}s"
    )
  end

  def on_failure(time)
  end

  private

  def configure_check
    @uri = gen_uri
    user_headers = @user_defined_config['headers'] || {}
    @headers = AppConfig.check_defaults.headers.merge(user_headers)
    @next_time = Time.now.utc.to_f
    @frequency = @user_defined_config['frequency'] || AppConfig.check_defaults.frequency
    @requests = {}
  end

  def gen_uri
    host = @user_defined_config['host']
    raise ArgumentError('No host provided') unless host

    protocol = @user_defined_config['protocol'] || AppConfig.check_defaults.protocol
    endpoint = @user_defined_config['endpoint'] || AppConfig.check_defaults.endpoint
    URI("#{protocol}://#{host}#{endpoint}")
  end
end
  