require 'semantic_logger'
require 'faraday'

class RubyUptime::Check

  include SemanticLogger::Loggable
  attr_accessor :last_time
  attr_reader :next_time, :name, :uri, :reqs

  # set defaults
  @@DEFAULT_CHECK_FREQUENCY = ENV['DEFAULT_CHECK_FREQUENCY'] || 10
  @@DEFAULT_CHECK_PROTOCOL = ENV['DEFAULT_CHECK_PROTOCOL'] || 'https'
  @@DEFAULT_CHECK_ENDPOINT = ENV['DEFAULT_CHECK_ENDPOINT'] || '/'
  @@DEFAULT_CHECK_TIMEOUT = ENV['DEFAULT_CHECK_TIMEOUT'] || '10'

  def self.log_header
    logger.info(
      "Check Time - Check Name - Check Status - Check Body - Next Check Due Time - \
Duration"
  )
  end

  def initialize(options = {})
    self.name = options['name']
    @uri = gen_uri options
    @next_time = Time.now.utc.to_f
    @frequency = options['frequency'] || @@DEFAULT_CHECK_FREQUENCY
    @reqs = {}
  rescue ArgumentError => e
    logger.warn "Error creating check. Ignoring: #{e}"
    @valid = false
    nil
  end

  def name=(name)
    raise ArgumentError.new('No name provided') unless name

    @name = name
  end

  def host=(host)
    raise ArgumentError.new('No host provided') unless host

    @host = host
  end

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

  def gen_uri(options)
    host = options['host']
    raise ArgumentError('No host provided') unless host

    protocol = options['protocol'] || @@DEFAULT_CHECK_PROTOCOL
    endpoint = options['endpoint'] || @@DEFAULT_CHECK_ENDPOINT
    Faraday::Utils::URI("#{protocol}://#{host}#{endpoint}")
  end
end
  