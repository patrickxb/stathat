require 'net/http'
require 'uri'
require 'json'
require 'thread'
require 'singleton'

module StatHat
        class API
                class << self
                        def ez_post_value(stat_name, ezkey, value, timestamp=nil, &block)
                                Reporter.instance.ez_post_value(stat_name, ezkey, value, timestamp, block)
                        end

                        def ez_post_count(stat_name, ezkey, count, timestamp=nil, &block)
                                Reporter.instance.ez_post_count(stat_name, ezkey, count, timestamp, block)
                        end

                        def post_count(stat_key, user_key, count, timestamp=nil, &block)
                                Reporter.instance.post_count(stat_key, user_key, count, timestamp, block)
                        end

                        def post_value(stat_key, user_key, value, timestamp=nil, &block)
                                Reporter.instance.post_value(stat_key, user_key, value, timestamp, block)
                        end
                end
        end

        class Reporter
                include Singleton

                CLASSIC_VALUE_URL = "http://api.stathat.com/v"
                CLASSIC_COUNT_URL = "http://api.stathat.com/c"
                EZ_URL = "http://api.stathat.com/ez"

                def initialize
                        @que = Queue.new
                        @runlock = Mutex.new
                        run_pool()
                end

                def finish()
                        stop_pool
                        # XXX serialize queue?
                end

                def post_value(stat_key, user_key, value, timestamp, cb)
                        args = { :key => stat_key,
                                :ukey => user_key,
                                :value => value }
                        args[:t] = timestamp unless timestamp.nil?
                        enqueue(CLASSIC_VALUE_URL, args, cb)
                end

                def post_count(stat_key, user_key, count, timestamp, cb)
                        args = { :key => stat_key,
                                :ukey => user_key,
                                :count => count }
                        args[:t] = timestamp unless timestamp.nil?
                        enqueue(CLASSIC_COUNT_URL, args, cb)
                end

                def ez_post_value(stat_name, ezkey, value, timestamp, cb)
                        puts "ezval cb: #{cb}"
                        args = { :stat => stat_name,
                                :ezkey => ezkey,
                                :value => value }
                        args[:t] = timestamp unless timestamp.nil?
                        enqueue(EZ_URL, args, cb)
                end

                def ez_post_count(stat_name, ezkey, count, timestamp, cb)
                        args = { :stat => stat_name,
                                :ezkey => ezkey,
                                :count => count }
                        args[:t] = timestamp unless timestamp.nil?
                        enqueue(EZ_URL, args, cb)
                end

                private
                def run_pool
                        @runlock.synchronize { @running = true }
                        @pool = []
                        5.times do |i|
                                @pool[i] = Thread.new do
                                        puts "thread #{i} started"
                                        while true do
                                                point = @que.pop
                                                # XXX check for error?
                                                begin
                                                        puts "thread #{i}: sending"
                                                        resp = send_to_stathat(point[:url], point[:args])
                                                        if point[:cb]
                                                                point[:cb].call(resp)
                                                        end
                                                rescue
                                                        pp $!
                                                end
                                                @runlock.synchronize {
                                                        break unless @running
                                                }
                                        end
                                        puts "reporter thread #{i} finished"
                                end
                        end
                end

                def stop_pool()
                        @runlock.synchronize {
                                @running = false
                        }
                        @pool.each do |th|
                                th.join if th && th.alive?
                        end
                end

                def enqueue(url, args, cb=nil)
                        return false unless @running
                        point = {:url => url, :args => args, :cb => cb}
                        @que << point
                        true
                end

                def send_to_stathat(url, args)
                        uri = URI.parse(url)
                        uri.query = URI.encode_www_form(args)
                        resp = Net::HTTP.get(uri)
                        return Response.new(resp)
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
