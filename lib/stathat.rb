require 'net/http'
require 'cgi'
require 'uri'
require 'json'
require 'thread'
require 'singleton'

module StatHat
        class Common
                CLASSIC_VALUE_URL = "http://api.stathat.com/v"
                CLASSIC_COUNT_URL = "http://api.stathat.com/c"
                EZ_URL = "http://api.stathat.com/ez"

                class << self
                       # def send_to_stathat(url, args)
                       #         uri = URI.parse(url)
                       #         uri.query = URI.encode_www_form(args)
                       #         resp = Net::HTTP.get(uri)
                       #         return Response.new(resp)
                       # end

                        def send_to_stathat(url, args)
                                uri = URI.parse(url)

                                begin
                                        uri.query = URI.encode_www_form(args)
                                rescue NoMethodError => e
                                        # backwards compatability for pre 1.9.x
                                        uri.query = args.map { |arg, val| arg.to_s + "=" + CGI::escape(val.to_s) }.join('&')
                                end

                                resp = Net::HTTP.get(uri)
                                return Response.new(resp)
                        end
                end
        end

        class SyncAPI
                class << self
                        def ez_post_value(stat_name, ezkey, value, timestamp=nil)
                                args = { :stat => stat_name,
                                        :ezkey => ezkey,
                                        :value => value }
                                args[:t] = timestamp unless timestamp.nil?
                                Common::send_to_stathat(Common::EZ_URL, args)
                        end

                        def ez_post_count(stat_name, ezkey, count, timestamp=nil)
                                args = { :stat => stat_name,
                                        :ezkey => ezkey,
                                        :count => count }
                                args[:t] = timestamp unless timestamp.nil?
                                Common::send_to_stathat(Common::EZ_URL, args)
                        end

                        def post_count(stat_key, user_key, count, timestamp=nil)
                                args = { :key => stat_key,
                                        :ukey => user_key,
                                        :count => count }
                                args[:t] = timestamp unless timestamp.nil?
                                Common::send_to_stathat(Common::CLASSIC_COUNT_URL, args)
                        end

                        def post_value(stat_key, user_key, value, timestamp=nil)
                                args = { :key => stat_key,
                                        :ukey => user_key,
                                        :value => value }
                                args[:t] = timestamp unless timestamp.nil?
                                Common::send_to_stathat(Common::CLASSIC_VALUE_URL, args)
                        end
                end
        end

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

                def initialize
                        @que = Queue.new
                        @running = false
                        run_pool()
                end

                def finish()
                        stop_pool
                        # XXX serialize queue?
                end

                def running?
                  @running
                end

                def post_value(stat_key, user_key, value, timestamp, cb)
                        args = { :key => stat_key,
                                :ukey => user_key,
                                :value => value }
                        args[:t] = timestamp unless timestamp.nil?
                        enqueue(Common::CLASSIC_VALUE_URL, args, cb)
                end

                def post_count(stat_key, user_key, count, timestamp, cb)
                        args = { :key => stat_key,
                                :ukey => user_key,
                                :count => count }
                        args[:t] = timestamp unless timestamp.nil?
                        enqueue(Common::CLASSIC_COUNT_URL, args, cb)
                end

                def ez_post_value(stat_name, ezkey, value, timestamp, cb)
                        args = { :stat => stat_name,
                                :ezkey => ezkey,
                                :value => value }
                        args[:t] = timestamp unless timestamp.nil?
                        enqueue(Common::EZ_URL, args, cb)
                end

                def ez_post_count(stat_name, ezkey, count, timestamp, cb)
                        args = { :stat => stat_name,
                                :ezkey => ezkey,
                                :count => count }
                        args[:t] = timestamp unless timestamp.nil?
                        enqueue(Common::EZ_URL, args, cb)
                end

                private
                def run_pool
                        @running = true
                        @pool = []
                        5.times do |i|
                                @pool[i] = Thread.new do
                                        while (point = @que.pop) != :quit
                                                # XXX check for error?
                                                begin
                                                        resp = Common::send_to_stathat(point[:url], point[:args])
                                                        if point[:cb]
                                                                point[:cb].call(resp)
                                                        end
                                                rescue
                                                        pp $!
                                                end
                                        end
                                end
                        end
                end

                def stop_pool()
                        @running = false

                        # Each thread will stop after it receives
                        # `:quit` instead of a hash of stat
                        # information. Sending `@pool.length` quit
                        # messages ensures that all threads will be
                        # woken up, and thus avoid deadlocks.
                        @pool.length.times { @que << :quit }

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
