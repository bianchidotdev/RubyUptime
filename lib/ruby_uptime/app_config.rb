APP_ENV = ENV['ENV'] || 'development'

AppConfig = Figgy.build do |config|
  config.root = File.expand_path(File.join(PROJECT_ROOT, 'etc'))

  # config.foo is read from etc/foo.yml
  config.define_overlay :default, nil

  config.define_overlay(:environment) { APP_ENV }
end
