require 'singleton'

class RubyUptime::UserConfig
  include Singleton

  attr_reader :checks, :config_files

  def initialize
    @config_files = files
  end

  def checks
    @checks ||=begin
      merge_checks_with_defaults
    end
  end

  def [](key)
    checks[key]
  end

  private

  def files
    @files ||=begin
      dir = AppConfig.paths.check_config_dir
      files = Dir["#{dir}/**/*.yml*"]
      files << Dir["#{dir}/**/*.json"]
      files.delete(default_config_path)
      logger.debug("Found check config files #{files.join(", ")}")
      files.flatten
    end
  end

  def default_config_path
    "#{AppConfig.paths.check_config_dir}/#{AppConfig.paths.check_defaults_file}"
  end

  def user_defaults
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

  def merge_checks_with_defaults
    check_config.map do |key, config|
      default = config.dig('default') || 'default'
      logger.warn("Could not find user-defined default: #{default} - using 'default'") unless user_defaults[default] 
      default_config = user_defaults[default]
      # prior hash gets overriden by successive hash
      merged_config = default_config.merge(config) if default_config
      # returns a hash of merged config
      # https://stackoverflow.com/a/25666112/8418673
      [key, merged_config]
    end.to_h
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