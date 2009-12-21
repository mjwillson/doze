# Various stateless utility functions which aid the conversion back and forth between HTTP syntax and the more abstracted ruby representations we use.
module Rack::REST::Utils
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

  def absolute_resource_uri_based_on_request_uri(request, resource)
    request_base_uri(request).merge(resource.uri)
  end

  def quote(str)
    '"' << str.gsub(/[\\\"]/o, "\\\1") << '"'
  end

  # So utility functions are accessible as Rack::REST::Utils.foo as well as via including the module
  extend self
end
