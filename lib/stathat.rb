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
                EZ_URI = URI(EZ_URL)

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
                                return Response.new(resp)
                        end

                        def send_ez_batch_to_stathat(batch_args, ezkey)
                             resp = Net::HTTP.start(EZ_URI.host, EZ_URI.port, :use_ssl => true) do |http|
                                    http.post EZ_URI.path,
                                                   { :ezkey => ezkey, :data => batch_args }.to_json,
                                                   "Content-Type" => "application/json"
                            end
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
                        attr_accessor :max_batch
                        attr_accessor :pool_size
                        attr_accessor :max_queue_size
                        attr_accessor :batch_sleep_seconds

                        def ez_post_value(stat_name, ezkey, value, timestamp=Time.now.to_i, &block)
                                Reporter.instance.ez_post_value(stat_name, ezkey, value, timestamp, block)
                        end

                        def ez_post_count(stat_name, ezkey, count, timestamp=Time.now.to_i, &block)
                                Reporter.instance.ez_post_count(stat_name, ezkey, count, timestamp, block)
                        end

                        def post_count(stat_key, user_key, count, timestamp=Time.now.to_i, &block)
                                Reporter.instance.post_count(stat_key, user_key, count, timestamp, block)
                        end

                        def post_value(stat_key, user_key, value, timestamp=Time.now.to_i, &block)
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
                        (API.pool_size || 5).times do |i|
                                @pool[i] = Thread.new do
                                        while true do
                                                points = [@que.pop]
                                                while points.size < (API.max_batch || 1) && @que.length > 0
                                                    points << @que.pop(true) rescue ThreadError
                                                end

                                                groups = points.group_by{|point| point[:args][:ezkey]}
                                                groups.each do |ezkey, batch|
                                                    if ezkey.nil?
                                                        batch.each do |point|
                                                            # XXX check for error?
                                                            begin
                                                                    resp = Common::send_to_stathat(point[:url], point[:args])
                                                                    if point[:cb]
                                                                            point[:cb].call(resp)
                                                                    end
                                                            rescue
                                                                    p $!
                                                            end
                                                        end

                                                    else
                                                        batch_args = batch.map{|point| point[:args]}
                                                        batch_args.each{|args| args.delete(:ezkey)}

                                                        begin
                                                                resp = Common::send_ez_batch_to_stathat(batch_args, ezkey)
                                                                batch.each do |point|
                                                                    if point[:cb]
                                                                            point[:cb].call(resp)
                                                                    end
                                                                end
                                                        rescue
                                                                p $!
                                                        end
                                                    end
                                                end

                                                @runlock.synchronize {
                                                        break unless @running
                                                }

                                                sleep API.batch_sleep_seconds unless API.batch_sleep_seconds.nil?
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
                        if API.max_queue_size && @que.length > API.max_queue_size
                                puts "Dropping StatHat queue"
                                @que.clear
                        end
                        point = {:url => url, :args => args, :cb => cb}
                        @que << point
                        true
                end
        end

        class Response
                def initialize(resp)
                        @resp = resp
                        @parsed = nil
                end

                def success?
                        return valid? && (@resp.body.nil? || msg == "ok")
                end

                def valid?
                        return @resp.body.nil? ? @resp.kind_of?(Net::HTTPSuccess) : status == 200
                end

                def status
                        parse
                        return @resp.body.nil? ? @resp.status : @parsed['status']
                end

                def msg
                        parse
                        return @resp.body.nil? ? nil : @parsed['msg']
                end

                private
                def parse
                        return unless @parsed.nil?
                        return if @resp.body.nil?
                        @parsed = JSON.parse(@resp.body)
                end
        end
end
