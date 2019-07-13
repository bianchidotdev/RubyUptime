class RubyUptime::UserConfig
  attr_reader :check_config, :config_files

  def initialize
    @config_files = files
    user_defaults = load_default_config
    checks = check_config
    # @check_config = merge_checks_with_defaults(checks, user_defaults)
    # need to merge with default key || default
  end

  private

  def files
    dir = AppConfig.paths.check_config_dir
    files = Dir["#{dir}/**/*.yml*"]
    files << Dir["#{dir}/**/*.json"]
    files.delete(default_config_path)
    logger.debug("Found check config files #{files.join(", ")}")
    files.flatten
  end

  def default_config_path
    "#{AppConfig.paths.check_config_dir}/#{AppConfig.paths.check_defaults_file}"
  end

  def load_default_config
    load_file(default_config_path) if File.file?(default_config_path)
  end

  def check_config
    @check_config ||=begin
      checks_array = files.map { |file| load_file(file) }.reject{ |c| !c }
      checks_keys = checks_array.flat_map { |e| e.keys }
      dups = checks_keys.group_by{ |e| e }.keep_if{ |_, e| e.length > 1 }
      logger.warn("Duplicate checks exist! There may be strange merging behavior: #{dups.keys.join(', ')}") unless dups.empty?
      checks_array.reduce(:merge)
    end
  end

  def load_file(filename)
    contents = File.read(filename)
    case
    when filename.match?(/\.yml$/)
      YAML.load(contents)
    when filename.match?(/\.yml.erb$/)
      erb = ERB.new(contents).result
      YAML.load(erb)
    when filename.match?(/\.json$/)
      JSON.parse(contents)
    end
  end
end