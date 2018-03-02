require 'net/http'
require 'cgi'
require 'uri'
require 'json'
require 'thread'
require 'singleton'

module StatHat
        class Common
                CLASSIC_VALUE_URL = "https://api.stathat.com/v"
                CLASSIC_COUNT_URL = "https://api.stathat.com/c"
                EZ_URL = "https://api.stathat.com/ez"

                class << self
                        def send_to_stathat(url, args)
                                uri = URI.parse(url)

                                begin
                                        uri.query = URI.encode_www_form(args)
                                rescue NoMethodError => e
                                        # backwards compatability for pre 1.9.x
                                        uri.query = args.map { |arg, val| arg.to_s + "=" + CGI::escape(val.to_s) }.join('&')
                                end

                                resp = Net::HTTP.get_response(uri)
                                return Response.new(resp.body, resp.code.to_i)
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
                        @runlock.synchronize { @running = true }
                        @pool = []
                        5.times do |i|
                                @pool[i] = Thread.new do
                                        while true do
                                                point = @que.pop
                                                # XXX check for error?
                                                begin
                                                        resp = Common::send_to_stathat(point[:url], point[:args])
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
        end

        class Response
                def initialize(body, http_status)
                        @body = body
                        @http_status = http_status
                        @parsed = nil
                end

                def valid?
                        return (200..299).cover? status
                end

                def status
                        if @body
                                parse
                                return @parsed['status']
                        else
                                return @http_status
                        end
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
