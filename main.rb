# TODO: implement service

require 'date'
require 'yaml'

require 'faraday'

require 'semantic_logger'

# TODO: move to networked DB
options = (YAML.load_file 'checks.yaml')

check_options = options['checks']
default_options = options['check_defaults']

# Set defaults
DEFAULT_CHECK_FREQUENCY = default_options['frequency'] || 10
DEFAULT_CHECK_PROTOCOL = default_options['protocol'] || 'https'
DEFAULT_CHECK_ENDPOINT = default_options['endpoint'] || '/testall'

def init_logger(logger_name)
  SemanticLogger.default_level = :trace
  SemanticLogger.add_appender(
    file_name: 'development.log', level: :info, formatter: :color
  )
  SemanticLogger.add_appender(
    io: $stdout, level: :debug, formatter: :color
  )

  logger = SemanticLogger[logger_name]

  logger
end

logger = init_logger 'simple_uptime_logger'

class InitializationInvalidError < StandardError; end

class Check
  include SemanticLogger::Loggable
  attr_accessor :last_time
  attr_reader :next_time, :name, :uri, :reqs

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
    @frequency = options['frequency'] || DEFAULT_CHECK_FREQUENCY
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
    # p self.reqs[time][:resp]
    logger.info(
      "#{Time.at(self.last_time).utc} - \
#{self.name} - \
#{self.reqs[time][:resp].status} - \
#{self.reqs[time][:resp].body} - \
#{Time.at(self.next_time).utc} - \
#{self.reqs[time][:duration].round(3)}s"
    )
  end

  def on_failure(time)
  end

  private

  def gen_uri(options)
    host = options['host']
    raise ArgumentError('No host provided') unless host

    protocol = options['protocol'] || DEFAULT_CHECK_PROTOCOL
    endpoint = options['endpoint'] || DEFAULT_CHECK_ENDPOINT
    Faraday::Utils::URI("#{protocol}://#{host}#{endpoint}")
  end
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
    resp, duration = check.eval(conn)
    request = {
      :resp => resp,
      :duration => duration,
    }
    check.add_request(time, request)

    check.successful? ? check.on_success(time) : check.on_failure(time)
    check.remove_request(time)
  end
end

checks = create_checks(check_options)

Check.log_header

threads = {}
loop do
  checks.each do |check|
    if check.next_time < Time.now.utc.to_f
      threads[Time.now.utc.to_f] = Thread.new { eval_check check, logger }
    end
    sleep 0.001
  end

  sleep 0.1

  # delete old threads
  threads.each do |time, thread|
    thread.kill if (time < Time.now.utc.to_f - 2)
  end

  threads = threads.select do |_time, thread|
    thread.alive?
  end

  logger.warn("Spawning too many threads - #{threads}") if threads.count > (checks.count * 3)
end
