require 'spec_helper'
require 'ruby_uptime'

RSpec.describe RubyUptime do
  describe 'project root' do
    include RubyUptime
    it 'is set and equals the absolute path of the project root' do
      expect(PROJECT_ROOT).to eq(File.dirname(File.expand_path('..', __FILE__)))
    end
  end

  describe 'figgy initializer' do
    include RubyUptime
    it 'contains application defaults' do
      expect(AppConfig.check_defaults).to_not be_empty
      expect(AppConfig.check_defaults.key?('protocol')).to be(true)
      expect(AppConfig.check_defaults.key?('endpoint')).to be(true)
      expect(AppConfig.check_defaults.key?('frequency')).to be(true)
      expect(AppConfig.check_defaults.key?('success_criteria')).to be(true)
    end

    it 'contains paths for core functionality' do
      expect(AppConfig.paths.key?('log_dir')).to be(true)
      expect(AppConfig.paths.key?('check_config_dir')).to be(true)
      expect(AppConfig.paths.key?('check_defaults_file')).to be(true)
    end
  end
end
