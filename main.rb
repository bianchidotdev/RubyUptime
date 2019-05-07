#TODO implement service
#TODO implement logging

require 'date'
require 'yaml'

require 'faraday'
require 'typhoeus/adapters/faraday'

# TODO move to yaml or DynamoDB
options = (YAML.load_file 'checks.yaml')

checkOptions = options["checks"]
defaultOptions = options["checkDefaults"]

DEFAULT_CHECK_FREQUENCY = defaultOptions["frequency"] || 10
DEFAULT_CHECK_PROTOCOL = defaultOptions["protocol"] || "https"
DEFAULT_CHECK_ENDPOINT = defaultOptions["endpoint"] || "/testall"

# checkOptions = [
#     {
#         :name => "testland-dev",
#         :host => "config.lab.testland.auth0.com",
#         :endpoint => "/testall",
#         :protocol => "https",
#         :frequency => 1,
#     },
#     {
#         :name => "testland-dev-1",
#         :host => "config.lab-1.testland.auth0.com",
#         :endpoint => "/testall",
#         :protocol => "https",
#         #:frequency => 10,
#     }
# ]

class Check
    attr_accessor :next_time, :last_time, :resps
    attr_reader :frequency, :name, :uri

    def initialize options={}
        # if not options["name"] && not options["host"] do
        #     p "Required information missing. Ignoring check: #{options}"
        #     return
        # end

        @name = options["name"]
        @uri = Faraday::Utils::URI("#{options["protocol"] || DEFAULT_CHECK_PROTOCOL}://#{options["host"]}#{options["endpoint"] || DEFAULT_CHECK_ENDPOINT}")
        @next_time = Time.now.utc.to_f
        @frequency = options["frequency"]
        @resps = Hash.new()
    end

    def eval conn
        conn.get @uri
    end

    def add_resp t, resp
        @resps[t] = resp
    end

    def remove_resp t
        @resps.delete(t)
    end

    private
    #TODO implement
    def gen_uri host #endpoint="/" protocol="https"
        Faraday::Utils::URI("#{options["protocol"]}://#{options["host"]}#{options["endpoint"]}")
    end
end

checks = []
for checkOption in checkOptions
    check = Check.new checkOption
    checks << check
end

def eval_checks checks
    t = Time.now.utc.to_f
    evaluatedChecks = []
    conn = Faraday::Connection.new() do |c|
        c.adapter :typhoeus
    end

    conn.in_parallel do
        for check in checks
            if check.next_time < t
                # set check time
                check.last_time = t
                check.next_time = check.next_time + (check.frequency || DEFAULT_CHECK_FREQUENCY)

                check.add_resp(t, check.eval(conn))

                evaluatedChecks << check
            end
        end
    end
    log_checks t, evaluatedChecks
end

def log_checks t, checks
    checks.each do |check|
        p "#{Time.at(check.last_time)} - #{check.name} - #{check.resps[t].status} - #{check.resps[t].body} - #{Time.at(check.next_time)}"
        # p check.resps[t]
        check.remove_resp(t)
    end
end

threads = Hash.new()
while true
    threads[Time.now.utc.to_f] = Thread.new { eval_checks checks }

    # delete old threads

    sleep 0.1
    threads.each do |t, thread|
        if t < Time.now.utc.to_f - 2
            thread.kill
        end
    end
    threads = threads.select do |t, thread|
        thread.alive?
    end
end