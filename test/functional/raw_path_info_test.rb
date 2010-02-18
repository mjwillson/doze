require "test/unit"
require 'mocha'
require 'doze/request'

class RawPathInfoTest < Test::Unit::TestCase
  include Doze::Utils
  include Doze::TestCase

  def mock_request(path, host="localhost", scheme="http", port=-1, context="")

    port_str = if port == -1 then "" ; else ":#{port}" ; end

    url = stub()
    url.stubs(:toString).returns("#{scheme}://#{host}#{port_str}#{path}")

    s_request = stub("")
    s_request.stubs(:getRequestURL).returns(url)
    s_request.stubs(:getContextPath).returns(context)

    app = stub()
    env = stub()
    env.stubs(:[]).with('java.servlet.request').returns(s_request)
    Doze::Request.new(app, env)
  end

  def test_bland_path
    dr = mock_request("/path/is/good")
    assert_equal dr.raw_path_info, "/path/is/good"
  end

  def test_path_with_host_and_port
    dr = mock_request("/how/do", "awesome-server", 5432)
    assert_equal dr.raw_path_info, "/how/do"
  end

  def test_path_with_naughty_chars
    dr = mock_request("/how/do%20", "awesome-server", 5432)
    assert_equal dr.raw_path_info, "/how/do%20"
  end

  def test_servlet_is_missing
    app = stub()
    env = stub()
    env.stubs(:[]).with('java.servlet.request').returns(nil)
    dr = Doze::Request.new(app, env)
    dr.expects(:path_info).twice.returns("/omg/im/a/path")
    assert_equal dr.raw_path_info, dr.path_info
  end

end
