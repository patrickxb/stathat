require 'net/http'
require 'uri'
require 'json'

module StatHat
        class API
                CLASSIC_VALUE_URL = "http://api.stathat.com/v"
                CLASSIC_COUNT_URL = "http://api.stathat.com/c"
                EZ_URL = "http://api.stathat.com/ez"

                def self.post_value(stat_key, user_key, value)
                        args = { :key => stat_key,
                                :ukey => user_key,
                                :value => value }
                        return self.send_to_stathat(CLASSIC_VALUE_URL, args)
                end

                def self.post_count(stat_key, user_key, count)
                        args = { :key => stat_key,
                                :ukey => user_key,
                                :count => count }
                        return self.send_to_stathat(CLASSIC_COUNT_URL, args)
                end

                def self.ez_post_value(stat_name, ezkey, value)
                        args = { :stat => stat_name,
                                :ezkey => ezkey,
                                :value => value }
                        return self.send_to_stathat(EZ_URL, args)
                end

                def self.ez_post_count(stat_name, ezkey, count)
                        args = { :stat => stat_name,
                                :ezkey => ezkey,
                                :count => count }
                        return self.send_to_stathat(EZ_URL, args)
                end

                def self.send_to_stathat(url, args)
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
