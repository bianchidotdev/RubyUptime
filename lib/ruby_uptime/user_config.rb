class RubyUptime::UserConfig
  def initialize
    files
  end

  private

  def files
    dir = AppConfig.paths.check_config_dir
    logger.debug(Dir["#{dir}/**/*.yml*"])
  end
end