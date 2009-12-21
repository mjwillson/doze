require 'functional/base'

class CacheHeaderTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_with_no_cache_headers
    root.expects(:cacheable?).returns(nil).once
    get
    assert_nil last_response.headers['Cache-Control']
    assert_nil last_response.headers['Expires']
    assert_response_header_exists 'Etag'
  end

  def test_not_cacheable
    root.expects(:cacheable?).returns(false).once
    get
    assert_response_header_includes 'Cache-Control', 'no-cache'
    assert_response_header_includes 'Cache-Control', 'max-age=0'
    assert Time.httpdate(last_response.headers['Expires']) < Time.now
    assert_no_response_header 'Last-Modified'
  end

  def test_cacheable_but_no_expiry
    root.expects(:cacheable?).returns(true).at_least_once
    get
    assert_response_header_not_includes 'Cache-Control', 'no-cache'
    assert_response_header_not_includes 'Cache-Control', 'max-age'
    assert_response_header_includes 'Cache-Control', 'public'
    assert_nil last_response.headers['Expires']
    assert_response_header_exists 'Etag'
  end

  def test_cacheable_with_expiry
    root.expects(:cacheable?).returns(true).at_least_once
    root.expects(:cache_expiry_period).returns(60).once
    get
    assert_response_header_includes 'Cache-Control', 'max-age=60'
    assert_response_header_includes 'Cache-Control', 'public'
    assert_in_delta Time.now+60, Time.httpdate(last_response.headers['Expires']), 1
    assert_response_header_exists 'Etag'
  end

  def test_last_modified
    while_ago = Time.now - 30
    root.expects(:last_modified).returns(while_ago).at_least_once
    get
    assert_response_header 'Last-Modified', while_ago.httpdate
  end

  def test_private_cacheable
    root.expects(:cacheable?).returns(true).once
    root.expects(:publicly_cacheable?).returns(false).once
    root.expects(:cache_expiry_period).returns(60).once
    get
    assert_response_header_includes 'Cache-Control', 'max-age=60'
    assert_response_header_not_includes 'Cache-Control', 's-maxage'
    assert_response_header_not_includes 'Cache-Control', 'public'
    assert_response_header_includes 'Cache-Control', 'private'
    assert_in_delta Time.now+60, Time.httpdate(last_response.headers['Expires']), 1
    assert_response_header_exists 'Etag'
  end

  def test_cacheable_with_different_public_private_expiry
    root.expects(:cacheable?).returns(true).at_least_once
    root.expects(:cache_expiry_period).returns(60).once
    root.expects(:public_cache_expiry_period).returns(30).once
    get
    assert_response_header_includes 'Cache-Control', 'max-age=60'
    assert_response_header_includes 'Cache-Control', 's-maxage=30'
    assert_response_header_includes 'Cache-Control', 'public'
    assert_response_header_not_includes 'Cache-Control', 'private'
    assert_in_delta Time.now+60, Time.httpdate(last_response.headers['Expires']), 1
    assert_response_header_exists 'Etag'
  end
end
