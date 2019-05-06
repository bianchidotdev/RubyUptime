#TODO implement service
#TODO implement logging

require 'date'

require 'faraday'
require 'typhoeus/adapters/faraday'

DEFAULT_CHECK_FREQUENCY = 10

# TODO move to yaml or DynamoDB
checkOptions = [
    {
        :name => "testland-dev",
        :host => "config.lab.testland.auth0.com",
        :endpoint => "/testall",
        :protocol => "https",
        :frequency => 1,
    },
    {
        :name => "testland-dev-1",
        :host => "config.lab-1.testland.auth0.com",
        :endpoint => "/testall",
        :protocol => "https",
        #:frequency => 10,
    }
]

class Check
    attr_accessor :next
    attr_reader :frequency, :name, :uri

    def initialize options={}
        @name = options[:name]
        @uri = Faraday::Utils::URI("#{options[:protocol]}://#{options[:host]}#{options[:endpoint]}")
        @next = Time.now.utc
        @frequency = options[:frequency]
    end

    def eval
        Faraday.get @uri
    end

    private
    #TODO implement
    def gen_uri host #endpoint="/" protocol="https"
        Faraday::Utils::URI("#{options[:protocol]}://#{options[:host]}#{options[:endpoint]}")
    end
end

checks = []
for checkOption in checkOptions
    check = Check.new checkOption
    checks << check
end

def eval_checks checks
    t = Time.now.utc
    conn = Faraday::Connection.new() do |c|
        c.adapter :typhoeus
    end
    respAry = []
    conn.in_parallel do
        for check in checks
            # p check
            if check.next < t
                check.next = check.next + (check.frequency || DEFAULT_CHECK_FREQUENCY)
                # TODO implement async
                resp = conn.get do |req|
                    req.url "#{check.uri}"
                end
                respAry << resp
                p respAry
                puts "#{check.name} - #{resp.status}"
            end
        end
    end
    p respAry.map{ |resp| resp.status}
end

while true
    eval_checks checks
    sleep 1
end