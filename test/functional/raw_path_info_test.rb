require "test/unit"
require 'mocha'
require 'doze/request'

class RawPathInfoTest < Test::Unit::TestCase
  include Doze::Utils
  include Doze::TestCase

  def mock_request(path, host="localhost", scheme="http", port=-1, context="")

    port_str = if port == -1 then "" ; else ":#{port}" ; end

    path_parts = ["/", context, path].join("")
    if path_parts[0...2] == "//" then path_parts = path_parts[1..-1] end

    url = stub()
    url.stubs(:toString).returns("#{scheme}://#{host}#{port_str}#{path_parts}")

    s_request = stub("")
    s_request.stubs(:getRequestURL).returns(url)
    s_request.stubs(:getContextPath).returns(context)

    app = stub()
    env = stub()
    env.stubs(:[]).with('java.servlet_request').returns(s_request)
    Doze::Request.new(app, env)
  end

  def test_bland_path
    dr = mock_request("/path/is/good")
    assert_equal dr.raw_path_info, "/path/is/good"
  end

  def test_path_with_host_and_port
    dr = mock_request("/how/do", "x23.awesome-server.playlouder---com.com", 5432)
    assert_equal dr.raw_path_info, "/how/do"
  end

  def test_path_with_naughty_chars
    dr = mock_request("/how/do%20", "awesome-server", 5432)
    assert_equal dr.raw_path_info, "/how/do%20"
  end

  def test_context_is_chomped
    ['bob', 'bob-y', 'the%20bobster'].each do |context|
      dr = mock_request('/path-s/of/life', 'www.awesome.com', 'https', 8080, context)
      assert_equal dr.raw_path_info, "/path-s/of/life"
    end
  end

  def test_searchpart_excluded
    {
      '/path' => '/path', '?false=true' => '/', '/path?you=suck&bob&nick=awesome' => '/path'
    }.each do |raw, exp_raw_path_info|
      dr = mock_request(raw, 'some.host-rocks', 'http', 1234)
      assert_equal dr.raw_path_info, exp_raw_path_info
    end
  end

  def test_servlet_is_missing
    app = stub()
    env = stub()
    env.stubs(:[]).with('java.servlet_request').returns(nil)
    dr = Doze::Request.new(app, env)
    dr.expects(:path_info).twice.returns("/omg/im/a/path")
    assert_equal dr.raw_path_info, dr.path_info
  end

end
