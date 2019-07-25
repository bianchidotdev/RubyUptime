
$:.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'ruby_uptime'

include RubyUptime

check = RubyUptime::Check.new('testland-dev')



