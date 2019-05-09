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
  