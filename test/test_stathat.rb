require 'helper'


class TestStathat < MiniTest::Unit::TestCase

  def test_ez_value
    StatHat::API.ez_post_value("test ez value stat", "test@stathat.com", 0.92) do |resp|
      assert(resp.valid?, "response was invalid")
      assert_equal(resp.msg, "ok", "message should be 'ok'")
      assert_equal(resp.status, 200, "status should be 200")
    end
    sleep(1)
  end

  def test_ez_count
    StatHat::API.ez_post_value("test ez count stat", "test@stathat.com", 12) do |r|
      assert(r.valid?, "response was invalid")
      assert_equal(r.msg, "ok", "message should be 'ok'")
      assert_equal(r.status, 200, "status should be 200")
    end
    sleep(1)
  end

  def test_classic_count_bad_keys
    StatHat::API.post_count("XXXXXXXX", "YYYYYYYY", 12) do |r|
      assert_equal(r.valid?, false, "response was valid")
      assert_equal(r.msg, "invalid keys", "incorrect error message")
      assert_equal(r.status, 500, "incorrect status code")
    end
    sleep(1)
  end

  def test_classic_value_bad_keys
    StatHat::API.post_value("ZZZZZZZZ", "YYYYYYYYY", 0.92) do |r|
      assert_equal(r.valid?, false, "response was valid")
      assert_equal(r.msg, "invalid keys", "incorrect error message")
      assert_equal(r.status, 500, "incorrect status code")
    end
    sleep(1)
  end

  def test_ez_value_sync
    resp = StatHat::SyncAPI.ez_post_value("test ez value stat", "test@stathat.com", 0.92)
    assert(resp.valid?, "response was invalid")
    assert_equal(resp.status, 204, "status should be 200")
  end

  def test_ez_count_sync
    resp = StatHat::SyncAPI.ez_post_value("test ez count stat", "test@stathat.com", 12)
    assert(resp.valid?, "response was invalid")
    assert_equal(resp.status, 204, "status should be 200")
  end

  def test_classic_count_bad_keys_sync
    r = StatHat::SyncAPI.post_count("XXXXXXXX", "YYYYYYYY", 12)
    assert_equal(r.valid?, false, "response was valid")
    assert_equal(r.msg, "invalid keys", "incorrect error message")
    assert_equal(r.status, 500, "incorrect status code")
  end

  def test_classic_value_bad_keys_sync
    r = StatHat::SyncAPI.post_value("ZZZZZZZZ", "YYYYYYYYY", 0.92)
    assert_equal(r.valid?, false, "response was valid")
    assert_equal(r.msg, "invalid keys", "incorrect error message")
    assert_equal(r.status, 500, "incorrect status code")
  end
end
