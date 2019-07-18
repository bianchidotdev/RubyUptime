class RubyUptime::CheckManager
  # include SemanticLogger::Loggable

  attr_reader :checks
  def run!
    Check.log_header

    threads = {}
    loop do
      @checks.select(&:ready?).each do |check|
        threads[Time.now.utc.to_f] = Thread.new { eval_check(check) }
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
        check.valid? ? check : nil
      end.compact
    end
  end

  def load_user_config
    RubyUptime::UserConfig.instance
  end

  def eval_check(check)
    check.eval
  rescue StandardError => e
    logger.warn("Error checking host #{check.uri} - #{e.class}: #{e.message}")
  end
end
