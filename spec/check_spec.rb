require "spec_helper"
require 'pry'

require_relative '../lib/ruby_uptime/check'

describe 'Check' do


    describe '.new' do
        it "instantiates with required information" do
            mock_options = {
                'name' => "mocked check",
                'host' => "google.com"
            }
            check = Check.new(mock_options)
            expect(check).to be_instance_of(Check)
            expect(check.valid?).to be(true)
        end
    end

    describe '.valid' do
        it 'returns true if check has sufficient information' do
            mock_options = {
                'name' => "mocked check",
                'host' => "google.com"
            }
            check = Check.new(mock_options)
            expect(check.valid?).to be(true)
        end
        it "sets valid = false if not enough information" do
            check = Check.new()
            expect(check.valid?).to be(false)
        end
    end
end
