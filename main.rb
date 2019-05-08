# TODO: implement service
# TODO implement logging

require 'date'
require 'yaml'

# require 'opentracing'
# OpenTracing.global_tracer = TracerImplementation.new

require 'faraday'
# require 'faraday/tracer'
# require 'faraday_middleware'
# require 'typhoeus/adapters/faraday'

require 'semantic_logger'

# TODO: move to networked DB
options = (YAML.load_file 'checks.yaml')

checkOptions = options['checks']
defaultOptions = options['checkDefaults']

# Set defaults
DEFAULT_CHECK_FREQUENCY = defaultOptions['frequency'] || 10
DEFAULT_CHECK_PROTOCOL = defaultOptions['protocol'] || 'https'
DEFAULT_CHECK_ENDPOINT = defaultOptions['endpoint'] || '/testall'

def init_logger(logger_name)
  SemanticLogger.default_level = :trace
  SemanticLogger.add_appender(file_name: 'development.log', level: :info, formatter: :color)
  SemanticLogger.add_appender(io: $stdout, level: :debug, formatter: :color)

  logger = SemanticLogger[logger_name]

  # Logging.color_scheme( 'bright',
  #     :levels => {
  #         :info  => :green,
  #         :warn  => :yellow,
  #         :error => :red,
  #         :fatal => [:white, :on_red]
  #     },
  #     :date => :blue,
  #     :logger => :cyan,
  #     :message => :magenta
  # )
  # Logging.appenders.stdout(
  #   'stdout',
  #   :level  => :debug,
  #   :layout => Logging.layouts.pattern(
  #     :color_scheme => 'bright'
  #   )
  # )

  # Logging.appenders.rolling_file(
  #   'example.log',
  #   :level  => :info,
  #   :layout => Logging.layouts.json
  # )

  # logger = Logging.logger[logger_name]

  # logger.add_appenders 'stdout', 'example.log'
  logger
end

$logger = init_logger 'simple_uptime_logger'

class InitializationInvalidError < StandardError; end

class Check
  include SemanticLogger::Loggable
  attr_accessor :next_time, :last_time, :resps
  attr_reader :frequency, :name, :uri

  def initialize(options = {})
    if !options['name'] || !options['host']
      $logger.warn "Required information missing. Ignoring check: #{options}"
      @valid = false
      return
    end

    @name = options['name']
    @uri = Faraday::Utils::URI("#{options['protocol'] || DEFAULT_CHECK_PROTOCOL}://#{options['host']}#{options['endpoint'] || DEFAULT_CHECK_ENDPOINT}")
    @next_time = Time.now.utc.to_f
    @frequency = options['frequency']
    @resps = {}
  end

  def valid?
    @valid != false
  end

  def eval(conn)
    conn.get @uri
  end

  def add_resp(t, resp)
    @resps[t] = resp
  end

  def remove_resp(t)
    @resps.delete(t)
  end

  private

  # TODO: implement
  def gen_uri(_host) # endpoint="/" protocol="https"
    Faraday::Utils::URI("#{options['protocol']}://#{options['host']}#{options['endpoint']}")
  end
end

checks = []
checkOptions.each do |checkOption|
  check = Check.new checkOption
  checks << check if check.valid?
end

def eval_check(check)
  t = Time.now.utc.to_f

  conn = Faraday.new do |c|
    # c.use Faraday::Tracer, span: span
    c.adapter Faraday.default_adapter
  end
  # p "evaling #{check.name}"

  # set check time
  if check.next_time < t
    check.last_time = t
    check.next_time = check.next_time + (check.frequency || DEFAULT_CHECK_FREQUENCY)
    start_time = Time.now.utc.to_f
    check.add_resp(t, check.eval(conn))
    end_time = Time.now.utc.to_f
    duration = end_time - start_time
    log_check t, check, duration
  end
end

def log_check(t, check, duration)
  $logger.info "#{Time.at(check.last_time).utc} - #{check.name} - #{check.resps[t].status} - #{check.resps[t].body} - #{Time.at(check.next_time).utc} - #{duration.round(3)}s"
  check.remove_resp(t)
end

$logger.info 'Check Time - Check Name - Check Status - Check Body - Next Check Due Time - Duration'

threads = {}
loop do
  checks.each do |check|
    # p "#{check.name} - #{Time.at(check.next_time)}"
    if check.next_time < Time.now.utc.to_f
      # p check
      threads[Time.now.utc.to_f] = Thread.new { eval_check check }
    end
    sleep 0.01
  end

  sleep 0.1
  # delete old threads

  threads.each do |t, thread|
    thread.kill if t < Time.now.utc.to_f - 2
  end
  threads = threads.select do |_t, thread|
    thread.alive?
  end
end
