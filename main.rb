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
  attr_accessor :next_time, :last_time, :resps
  attr_reader :frequency, :name, :uri

  def initialize(options = {})
    self.name = options['name']
    @uri = gen_uri options
    @next_time = Time.now.utc.to_f
    @frequency = options['frequency'] || DEFAULT_CHECK_FREQUENCY
    @resps = {}
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

  def add_resp(time, resp)
    @resps[time] = resp
  end

  def remove_resp(time)
    @resps.delete(time)
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
    # c.use Faraday::Tracer, span: span
    c.adapter Faraday.default_adapter
  end
  # p "evaling #{check.name}"

  # set check time
  if check.next_time < time
    check.last_time = time
    check.next_time = check.next_time + check.frequency
    resp, duration = check.eval(conn)
    check.add_resp(time, resp)
    # eval_resp resp
    log_check time, check, duration, logger
  end
end

def log_check(time, check, duration, logger)
  logger.info(
    "#{Time.at(check.last_time).utc} - \
#{check.name} - \
#{check.resps[time].status} - \
#{check.resps[time].body} - \
#{Time.at(check.next_time).utc} - \
#{duration.round(3)}s"
  )
  check.remove_resp(time)
end

logger.info(
  'Check Time - Check Name - Check Status - Check Body - Next Check Due Time - \
  Duration'
)

checks = create_checks(check_options)

threads = {}
loop do
  checks.each do |check|
    # p "#{check.name} - #{Time.at(check.next_time)}"
    if check.next_time < Time.now.utc.to_f
      # p check
      threads[Time.now.utc.to_f] = Thread.new { eval_check check, logger }
    end
    sleep 0.001
  end

  sleep 0.1
  # delete old threads

  threads.each do |time, thread|
    thread.kill if time < Time.now.utc.to_f - 2
  end
  threads = threads.select do |_time, thread|
    thread.alive?
  end
end
