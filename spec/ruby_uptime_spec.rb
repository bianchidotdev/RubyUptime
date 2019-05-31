require 'spec_helper'

require_relative '../lib/ruby_uptime'

include RubyUptime

describe RubyUptime do
  describe '.init_logger' do
  end

  describe '.create_checks' do
    before do
      check_options = [{"name"=>"testland-dev",
        "host"=>"config.lab.testland.auth0.com",
        "frequency"=>1,
        "protocol"=>"https",
        "endpoint"=>"/testall",
        "timeout"=>10,
        "success_criteria"=>{"status"=>200, "body"=>"OK"}},
       {"name"=>"testland-dev-1",
        "host"=>"config.lab-1.testland.auth0.com",
        "frequency"=>10,
        "protocol"=>"https",
        "endpoint"=>"/testall",
        "timeout"=>10,
        "success_criteria"=>{"status"=>200, "body"=>"OK"}}]
        @checks = create_checks(check_options)
    end
    it 'creates multiple checks successfully' do
      expect(@checks.count).to eq(2)
      expect(@checks.map{|c| c.valid?}).to eq([true, true])
      expect(@checks.map{|c| c.uri.to_s}).to eq(['https://config.lab.testland.auth0.com/testall', 'https://config.lab-1.testland.auth0.com/testall'])
    end

  end

  describe '.eval_check' do
  end
end