require 'helper'


class TestStathat < MiniTest::Unit::TestCase
        def setup
                StatHat::API.pool_size = 1
                StatHat::API.max_batch = 2
        end

        def test_ez_value
                r = wait_for_resp do |cb|
                        StatHat::API.ez_post_value("test ez value stat", "test@stathat.com", 0.92, &cb)
                end
                assert_success(r)
        end

        def test_ez_count
                r = wait_for_resp do |cb|
                        StatHat::API.ez_post_count("test ez count stat", "test@stathat.com", 12, &cb)
                end
                assert_success(r)
        end

        def test_classic_count_bad_keys
                r = wait_for_resp do |cb|
                        StatHat::API.post_count("XXXXXXXX", "YYYYYYYY", 12, &cb)
                end
                assert_failure(r)
        end

        def test_classic_value_bad_keys
                r = wait_for_resp do |cb|
                        StatHat::API.post_value("ZZZZZZZZ", "YYYYYYYYY", 0.92, &cb)
                end
                assert_failure(r)
        end

        def test_ez_value_sync
                r = StatHat::SyncAPI.ez_post_value("test ez value stat", "test@stathat.com", 0.92)
                assert_success(r)
        end

        def test_ez_count_sync
                r = StatHat::SyncAPI.ez_post_count("test ez count stat", "test@stathat.com", 12)
                assert_success(r)
        end

        def test_classic_count_bad_keys_sync
                r = StatHat::SyncAPI.post_count("XXXXXXXX", "YYYYYYYY", 12)
                assert_failure(r)
        end

        def test_classic_value_bad_keys_sync
                r = StatHat::SyncAPI.post_value("ZZZZZZZZ", "YYYYYYYYY", 0.92)
                assert_failure(r)
        end

        def test_ez_batch
                final = wait_for_resp do |cb|
                        StatHat::API.post_count("XXXXXXXX", "YYYYYYYY", 11) do |r|
                                assert_failure(r)
                        end

                        StatHat::API.ez_post_value("test ez value stat", "test@stathat.com", 0.92) do |r|
                                assert_success(r)
                        end

                        StatHat::API.ez_post_count("test ez count stat", "test@stathat.com", 12) do |r|
                                assert_success(r)
                        end

                        StatHat::API.ez_post_count("test ez count stat2", "test@stathat.com", 13, &cb)
                end

                assert_success(final)
        end

        private

        def assert_success(r)
                assert(r.valid?, "response was invalid")
                assert_equal(r.msg, "ok", "message should be 'ok'")
                assert_equal(r.status, 200, "status should be 200")
        end

        def assert_failure(r)
                assert_equal(r.valid?, false, "response was valid")
                assert_equal(r.msg, "invalid keys", "incorrect error message")
                assert_equal(r.status, 500, "incorrect status code")
        end

        def wait_for_resp
                m = Mutex.new
                cv = ConditionVariable.new
                resp = nil

                cb = lambda do |r|
                        resp = r
                        m.synchronize do
                          cv.signal
                        end
                end

                m.synchronize do
                        yield cb
                        start = Time.now
                        assert cv.wait(m, 60)
                        assert Time.now - start < 50
                end

                resp
        end
end
