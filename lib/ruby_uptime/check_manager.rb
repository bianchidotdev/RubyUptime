class RubyUptime::CheckManager
  attr_reader :checks
  def run!
    Check.log_header

    threads = {}
    loop do
      @checks.each do |check|
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
  end

  def initialize
    @user_config = load_user_config
    @checks = create_checks
  end

  #private
  def create_checks
    @checks ||=begin
      @user_config.checks.keys.map do |check_config|
        check = Check.new(check_config)
        check if check.valid?
      end.compact
    end
  end

  def load_user_config
    RubyUptime::UserConfig.instance
  end

  def eval_check(check)
    time = Time.now.utc.to_f

    if check.next_time < time
      check.last_time = time
      check.set_next_time
      begin
        resp, duration = check.eval
      rescue StandardError => e
        logger.warn("Error checking host #{check.uri} - #{e.class}: #{e.message}")
      end
      request = {
        :resp => resp,
        :duration => duration,
      }
      check.add_request(time, request)

      check.successful? ? check.on_success(time) : check.on_failure(time)
      check.remove_request(time)
      check
    end
  end
end
