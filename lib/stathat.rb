require 'net/http'
require 'uri'
require 'json'
require 'thread'

module StatHat
        class API
                CLASSIC_VALUE_URL = "http://api.stathat.com/v"
                CLASSIC_COUNT_URL = "http://api.stathat.com/c"
                EZ_URL = "http://api.stathat.com/ez"

                REPORTER = self.new()

                def initialize()
                        @Q = Queue.new
                        run_pool()
                end

                def enqueue(url, args)
                        point = {:url => url, :args => args}
                        @Q << point
                end

                def run_pool()
                        @running = true
                        @pool = []
                        5.times do |i|
                                pool[i] = Thread.new do
                                        while @running do
                                                point = @Q.pop
                                                # XXX check for error?
                                                send_to_stathat(point[:url], point[:args])
                                        end
                                end
                        end
                end

                def stop_pool()
                        @running = false
                        @pool.each do |th|
                                th.join
                        end
                end

                def finish()
                        stop_pool
                        # XXX serialize queue?
                end

                def send_to_stathat(url, args)
                        uri = URI.parse(url)
                        uri.query = URI.encode_www_form(args)
                        resp = Net::HTTP.get(uri)
                        return Response.new(resp)
                end

                def post_value(stat_key, user_key, value)
                        args = { :key => stat_key,
                                :ukey => user_key,
                                :value => value }
                        enqueue(CLASSIC_VALUE_URL, args)
                end

                def self.post_value(stat_key, user_key, value)
                        REPORTER.post_value(stat_key, user_key, value)
                end

                def post_count(stat_key, user_key, count)
                        args = { :key => stat_key,
                                :ukey => user_key,
                                :count => count }
                        enqueue(CLASSIC_COUNT_URL, args)
                end

                def self.post_count(stat_key, user_key, count)
                        REPORTER.post_count(stat_key, user_key, count)
                end

                def ez_post_value(stat_name, ezkey, value)
                        args = { :stat => stat_name,
                                :ezkey => ezkey,
                                :value => value }
                        enqueue(EZ_URL, args)
                end

                def self.ez_post_value(stat_name, ezkey, value)
                        REPORTER.ez_post_value(stat_name, ezkey, value)
                end

                def ez_post_count(stat_name, ezkey, count)
                        args = { :stat => stat_name,
                                :ezkey => ezkey,
                                :count => count }
                        enqueue(EZ_URL, args)
                end

                def self.ez_post_count(stat_name, ezkey, count)
                        REPORTER.ez_post_count(stat_name, ezkey, count)
                end
        end

        class Response
                def initialize(body)
                        @body = body
                        @parsed = nil
                end

                def valid?
                        return status == 200
                end

                def status
                        parse
                        return @parsed['status']
                end

                def msg
                        parse
                        return @parsed['msg']
                end

                private
                def parse
                        return unless @parsed.nil?
                        @parsed = JSON.parse(@body)
                end
        end
end
