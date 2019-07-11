module RubyUptime
  NAME = "RubyUptime"
  LICENSE = "See LICENSE for licensing details."
end

require 'figgy'
require 'pry'

PROJECT_ROOT = File.expand_path('..', __dir__)
require 'ruby_uptime/app_config'
require 'ruby_uptime/check'
