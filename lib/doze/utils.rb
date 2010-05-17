# Various stateless utility functions which aid the conversion back and forth between HTTP syntax and the more abstracted ruby representations we use.
module Doze::Utils
  # Strictly this is a WebDAV extension but very useful in the wider HTTP context
  # see http://tools.ietf.org/html/rfc4918#section-11.2
  Rack::Utils::HTTP_STATUS_CODES[422] = 'Unprocessable entity'

  Rack::Utils::HTTP_STATUS_CODES.each do |code,text|
    const_set('STATUS_' << text.upcase.gsub(/[^A-Z]+/, '_'), code)
  end

  URI_SCHEMES = Hash.new(URI::Generic).merge!(
    'http' => URI::HTTP,
    'https' => URI::HTTPS
  )

  def request_base_uri(request)
    URI_SCHEMES[request.scheme].build(
      :scheme => request.scheme,
      :port => request.port,
      :host => request.host
    )
  end

  def quote(str)
    '"' << str.gsub(/[\\\"]/o, "\\\1") << '"'
  end

  # Rack::Utils.escape, but turning ' ' into '%20' rather than '+' (which is not a necessary part of the URI spec) to save an extra call to tr.
  # Also must be passed a string.
  def escape(s)
    s.gsub(/([^a-zA-Z0-9_.-]+)/n) {'%'+$1.unpack('H2'*bytesize($1)).join('%').upcase}
  end

  # Rack::Utils.unescape, but without turning '+' into ' '
  # Also must be passed a string.
  def unescape(s)
    s.gsub(/((?:%[0-9a-fA-F]{2})+)/n) {[$1.delete('%')].pack('H*')}
  end

  # So utility functions are accessible as Doze::Utils.foo as well as via including the module
  extend self
end
