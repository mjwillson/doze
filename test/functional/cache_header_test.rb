require 'functional/base'

class CacheHeaderTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_with_no_cache_headers
    root_resource.expects(:cacheable?).returns(nil).once
    get
    assert_nil last_response.headers['Cache-Control']
    assert_nil last_response.headers['Expires']
  end

  def test_not_cacheable
    root_resource.expects(:cacheable?).returns(false).once
    get
    assert_match /no-cache/, last_response.headers['Cache-Control']
    assert_match /max-age=0/, last_response.headers['Cache-Control']
    assert Time.httpdate(last_response.headers['Expires']) < Time.now
  end

  def test_cacheable_but_no_expiry
    root_resource.expects(:cacheable?).returns(true).at_least_once
    get
    assert_no_match /no-cache/, last_response.headers['Cache-Control']
    assert_no_match /max-age/, last_response.headers['Cache-Control']
    assert_match /public/, last_response.headers['Cache-Control']
    assert_nil last_response.headers['Expires']
  end

  def test_cacheable_with_expiry
    root_resource.expects(:cacheable?).returns(true).at_least_once
    root_resource.expects(:cache_expiry_period).returns(60).once
    get
    assert_match /max-age=60/, last_response.headers['Cache-Control']
    assert_match /public/, last_response.headers['Cache-Control']
    assert_in_delta Time.now+60, Time.httpdate(last_response.headers['Expires']), 1
  end

  def test_private_cacheable
    root_resource.expects(:cacheable?).returns(true).once
    root_resource.expects(:publicly_cacheable?).returns(false).once
    root_resource.expects(:cache_expiry_period).returns(60).once
    get
    assert_match /max-age=60/, last_response.headers['Cache-Control']
    assert_no_match /s-maxage/, last_response.headers['Cache-Control']
    assert_no_match /public/, last_response.headers['Cache-Control']
    assert_match /private/, last_response.headers['Cache-Control']
    assert_in_delta Time.now+60, Time.httpdate(last_response.headers['Expires']), 1
  end

  def test_cacheable_with_different_public_private_expiry
    root_resource.expects(:cacheable?).returns(true).at_least_once
    root_resource.expects(:cache_expiry_period).returns(60).once
    root_resource.expects(:public_cache_expiry_period).returns(30).once
    get
    assert_response_header_includes 'Cache-Control', 'max-age=60'
    assert_response_header_includes 'Cache-Control', 's-maxage=30'
    assert_response_header_includes 'Cache-Control', 'public'
    assert_response_header_not_includes 'Cache-Control', 'private'
    assert_in_delta Time.now+60, Time.httpdate(last_response.headers['Expires']), 1
  end
end
