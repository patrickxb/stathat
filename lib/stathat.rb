require 'net/http'
require 'uri'

module StatHat

        def post_value(stat_key, user_key, value)
                args = { :key => stat_key,
                        :ukey => user_key,
                        :value => value }
                resp = Net::HTTP.post_form(URI.parse("http://stathat.com/api/v"), args)
                return response_valid?(resp)
        end

        def post_count(stat_key, user_key, count)
                args = { :key => stat_key,
                        :ukey => user_key,
                        :value => value }
                resp = Net::HTTP.post_form(URI.parse("http://stathat.com/api/v"), args)
                return response_valid?(resp)
        end

        def ez_post_value(stat_name, account_email, value)
                args = { :stat => stat_name, 
                        :email => account_email, 
                        :value => value }
                resp = Net::HTTP.post_form(URI.parse("http://stathat.com/api/ez"), args)
                return response_valid?(resp)
        end

        def ez_post_count(stat_name, account_email, count)
                args = { :stat => stat_name, 
                        :email => account_email, 
                        :count => count }
                resp = Net::HTTP.post_form(URI.parse("http://stathat.com/api/ez"), args)
                return response_valid?(resp)
        end

        def response_valid?(response)
                return resp.body == "ok"
        end

end
