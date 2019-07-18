require 'semantic_logger'
require 'http'

class CheckCreationError < StandardError; end

class RubyUptime::Check

  include SemanticLogger::Loggable
  attr_accessor :last_time
  attr_reader :next_time, :id, :name, :uri, :requests, :error, :frequency, :headers

  def self.log_header
    logger.info(
      "Check Time - Check Name - Check Status - Check Body - Next Check Due Time - \
Duration"
  )
  end

  def initialize(id)
    @id = id
    user_config = UserConfig.instance
    raise CheckCreationError("could not find config for check #{id}") unless user_config[id]
    @user_defined_config = user_config[id]
    configure_check
  rescue StandardError => e
    logger.warn("Error creating check - #{e}")
    @error = "Error creating check - #{e}"
    @valid = false
  end

  def valid?
    @valid != false
  end

  def ready?
    @next_time < Time.now.utc
  end

  def eval!
    return unless ready?
    eval_id = gen_eval_id
    @last_time = Time.now.utc
    @next_time = @last_time + @frequency

    start_request(eval_id)

    successful?(eval_id) ? on_success(eval_id) : on_failure(eval_id)

    remove_request(eval_id)
    true
  end

  def start_request(eval_id)
    start_time = Time.now.utc.to_f
    @requests[eval_id] = {
      start_time: start_time,
    }
    resp = @http.get(@uri)
    end_time  = Time.now.utc.to_f
    duration = end_time - start_time
    @requests[eval_id][:resp] = resp
    @requests[eval_id][:duration] = duration
  rescue StandardError => e
    @requests[eval_id][:errors] = e
    on_failure(eval_id)
  end

  def remove_request(eval_id)
    @requests.delete(eval_id)
  end

  def successful?(eval_id)
    # TODO: Implement success criteria checking
    @requests[eval_id][:resp].status.success?
  end

  def on_success(eval_id)
    # TODO: Implement counter reset
    response = @requests[eval_id][:resp]
    status = response.status
    body = response.body
    duration = @requests[eval_id][:duration]
    logger.info(
      "#{@last_time} - #{@id} - #{status} - #{body} - #{@next_time} - \
#{duration.round(3)}s"
    )
  end

  def on_failure(eval_id)
    # TODO: Implement counter decrement
    logger.warn(
      "Check #{@id} failed - #{@requests[eval_id]}"
    )

  end

  private

  def gen_eval_id
    sprintf("%20.10f", Time.now.to_f).delete('.').to_i.to_s(36)
  end

  def configure_check
    @uri = gen_uri
    user_headers = @user_defined_config['headers'] || {}
    @headers = AppConfig.check_defaults.headers.merge(user_headers)
    @next_time = Time.now.utc
    @frequency = @user_defined_config['frequency'] || AppConfig.check_defaults.frequency
    @http = HTTP
      .headers(@headers)
      .follow(max_hops: 5)
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
  