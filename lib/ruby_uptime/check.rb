require 'semantic_logger'
require 'http'

class CheckCreationError < StandardError; end

module RubyUptime
  class Check

    attr_accessor :last_time
    attr_reader :next_time, :id, :name, :uri, :requests, :error, :frequency, :headers, :success_criteria

    def self.log_header
      logger.info(
        "Check Time - Check Name - Check Status - Check Body - Next Check Due Time - \
  Duration"
    )
    end

    def initialize(id)
      @id = id
      user_config = UserConfig.instance
      raise CheckCreationError.new("could not find config for check #{id}") unless user_config[id]
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

    def eval
      return unless ready?
      eval_id = gen_eval_id
      @last_time = Time.now.utc
      @next_time = @last_time + @frequency

      start_request(eval_id)

      if successful?(eval_id)
        logger.debug("Check successful - #{@name} with eval_id #{eval_id}")
      else
        logger.warn("Check failed - #{@name} with eval_id #{eval_id}")
      end

      remove_request(eval_id)
      true
    end

    def start_request(eval_id)
      start_time = Time.now.utc.to_f
      @requests[eval_id] = {
        start_time: start_time,
      }

      cert = nil
      resp = @http.start do |conn|
        resp = conn.get(@uri.request_uri)
        cert = conn.peer_cert if @uri.is_a?(URI::HTTPS) rescue nil
        resp
      end
      logger.error(resp.inspect)

      end_time  = Time.now.utc.to_f
      duration = end_time - start_time
      @requests[eval_id][:resp] = resp
      @requests[eval_id][:cert] = cert
      @requests[eval_id][:duration] = duration
      true
    rescue StandardError => e
      @requests[eval_id][:errors] = e
      @success_criteria.each_with_index { |_sc, i| on_failure(eval_id, i) }
      false
    end

    def remove_request(eval_id)
      @requests.delete(eval_id)
    end

    def successful?(eval_id)
      # TODO: Implement success criteria checking
      status = @requests[eval_id][:resp].code
      body = @requests[eval_id][:resp].body.to_s
      cert = @requests[eval_id][:cert]
      duration = @requests[eval_id][:duration]

      results = []
      results = @success_criteria.map do |sc|
        res = []
        res << (status == sc['status']) unless sc['status'].nil?
        res << body.include?(sc['body']) unless sc['body'].nil?
        res << cert_healthy?(cert, sc['ssl'])
        res << duration < sc['max_response_time'] unless sc['max_response_time'].nil?
        res.all?
      end

      @requests[eval_id][:results] = results
      results.each_with_index do |res, i|
        on_success(eval_id, i) if res
        on_failure(eval_id, i) unless res
      end
      # returns false if any are false
      results.all?
    end

    def on_success(eval_id, i)
      response = @requests[eval_id][:resp]
      status = response.code
      body = response.body
      duration = @requests[eval_id][:duration]

      @success_criteria[i]['counter'] = @success_criteria[i]['error_threshold']
      logger.info(
        "#{@last_time} - #{@id} - #{status} - #{body} - #{@next_time} - \
  #{duration.round(3)}s"
      )
    end

    def on_failure(eval_id, i)
      # TODO: Implement counter decrement
      @success_criteria[i]['counter'] -= 1
      if @success_criteria[i]['counter'] > 0
        logger.warn(
          "Check #{@id} failed - #{@requests[eval_id]} - #{@success_criteria[i]['counter']} of #{@success_criteria[i]['error_threshold']} failures before alarm"
        )
      else
        logger.warn(
          "Check #{@id} failed - #{@requests[eval_id]}"
        )
        alert(i)
      end
    end

    def alert(i)
    # TODO: Implement integrations
    end

    def cert_healthy?(_cert, _ssl_criteria)
    # TODO: Implement cert checking
    true
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
      @timeout = @user_defined_config['timeout'] || AppConfig.check_defaults.timeout
      @success_criteria = @user_defined_config['success_criteria'] || AppConfig.check_defaults.success_criteria
      @success_criteria = @success_criteria.map do |sc|
        sc['error_threshold'] = sc['error_threshold'] || AppConfig.check_defaults.error_threshold
        sc['counter'] = sc['error_threshold']
        sc
      end

      # Needed to switch to Net::HTTP from httprb to handle server cert checking
      @http = Net::HTTP.new(@uri.host, @uri.port).tap do |client|
        client.use_ssl = @uri.is_a?(URI::HTTPS)
        # don't think a total timeout is possible with Net::HTTP
        client.open_timeout = @timeout
        client.read_timeout = @timeout
      end
            
      # @http = HTTP
      #   .headers(@headers)
      #   .follow(max_hops: 5)
      #   .timeout(@timeout)
      @requests = {}
    end

    def gen_uri
      host = @user_defined_config['host']
      raise ArgumentError('No host provided') unless host

      @protocol = @user_defined_config['protocol'] || AppConfig.check_defaults.protocol
      endpoint = @user_defined_config['endpoint'] || AppConfig.check_defaults.endpoint
      URI.parse("#{@protocol}://#{host}#{endpoint}")
    end
  end
end
