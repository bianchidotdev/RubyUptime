require 'semantic_logger'
require 'http'

class CheckCreationError < StandardError; end

module RubyUptime
  class Check

    attr_accessor :last_time
    attr_reader :next_time, :id, :name, :uri, :requests, :error, :frequency, :headers, :success_criteria, :integrations

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
      # TODO: Rescue from invalid cert and set cert as failing
      # https://github.com/jarthod/ssl-test/blob/master/lib/ssl-test.rb
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
      status = @requests[eval_id][:resp].code.to_i
      body = @requests[eval_id][:resp].body.to_s
      cert = @requests[eval_id][:cert]
      duration = @requests[eval_id][:duration]

      raw_results = []
      results = @success_criteria.map do |sc|
        res = []
        raw_res = []
        res << (status == sc['status']) unless sc['status'].nil?
        raw_res << {status: {expected: sc['status'], got: status}} unless sc['status'].nil?
        res << body.include?(sc['body']) unless sc['body'].nil?
        raw_res << {body: {expected: sc['body'], got: body}} unless sc['body'].nil?
        cert_health, cert_errors = cert_healthy?(cert, sc['ssl']) unless sc['ssl'].nil?
        res << cert_health unless sc['ssl'].nil? # implement ssl ignore
        raw_res << {ssl: {expected: true, got: cert_health, errors: cert_errors}} unless sc['ssl'].nil?
        res << duration < sc['max_response_time'] unless sc['max_response_time'].nil?
        raw_res << {duration: {expected: sc['max_response_time'], got: duration}} unless sc['max_response_time'].nil?
        raw_results << raw_res
        res.all?
      end

      @requests[eval_id][:results] = results
      @requests[eval_id][:raw_results] = raw_results
      # this seems like a lot, but it's required for having separate counters for different succcess criteria
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

      # determine if it's a recovery if the previous counter 
      recovery = success_criteria[i]['counter'].positive? ? false : true
      @success_criteria[i]['counter'] = @success_criteria[i]['error_threshold']
      logger.info(
        "#{@last_time} - #{@id} - #{status} - #{body} - #{@next_time} - \
  #{duration.round(3)}s"
      )
      store_results(eval_id, true)
      # TODO: Success message to pagerduty
      alert_recovery(i) if recovery
    end

    def on_failure(eval_id, i)
      # TODO: Implement counter decrement
      @success_criteria[i]['counter'] -= 1
      num = @success_criteria[i]['counter']
      case
      when num.positive?
        logger.warn(
          "Check #{@id} failed - #{@requests[eval_id]} - #{@success_criteria[i]['counter']} of #{@success_criteria[i]['error_threshold']} failures before alarm"
        )
      when num.negative?
        logger.warn(
          "Check #{@id} failed - #{@requests[eval_id]} - check already in failure state"
        )
      when num.zero?
        logger.warn(
          "Check #{@id} failed - #{@requests[eval_id]} - alerting!"
        )
        alert(i)
      end
      store_results(eval_id, false)
    end

    def store_results(eval_id, success_status)
      # TODO: implement DB and such
    end

    def alert(i)
      integration_keys = @success_criteria[i]['integrations']
      integration_keys.each do |int_key|
        @integrations[int_key].trigger
      end
    # TODO: Implement integrations
    end

    def alert_recovery(i)
    end

    def cert_healthy?(cert, ssl_criteria)
      if ssl_criteria.key?('valid')
        # store = OpenSSL::X509::Store.new
        # store.set_default_paths # populates with some 'standard' ones
        # store.verify(cert) == ssl_criteria['valid']
      end
      if ssl_criteria.key?('expiry')

      end
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
      check_integrations = @user_defined_config['integrations']
      if check_integrations
        @integrations = {}
        check_integrations.each do |int_config|
          @integrations[int_config] = RubyUptime::Integration.new(int_config)
        end
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
