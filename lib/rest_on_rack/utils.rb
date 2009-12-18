# Various stateless utility functions which aid the conversion back and forth between HTTP syntax and the more abstracted ruby representations we use.
module Rack::REST::Utils
  Rack::Utils::HTTP_STATUS_CODES.each do |code,text|
    const_set('STATUS_' << text.upcase.gsub(/[^A-Z]+/, '_'), code)
  end

  def path_to_identifier_components(path)
    path.sub(/^\//,'').split('/').map {|component| Rack::Utils.unescape(component)}
  end

  def identifier_components_to_path(components)
    '/' + components.map {|component| Rack::Utils.escape(component)}.join('/')
  end

  def request_base_uri(request)
    # considered adding :path => request.script_name || '/'
    # but Addressable::URI's handling of relative URI paths isn't yet smart enough that we can use it to allow
    # resources to be unaware of the base path at which they're deployed.
    uri = Addressable::URI.new(
      :scheme => request.scheme,
      :port => request.port,
      :host => request.host
    )
    uri.port = uri.normalized_port
    uri
  end

  def absolute_resource_uri_based_on_request_uri(request, resource)
    request_base_uri(request).join(resource.uri)
  end

  def quote(str)
    '"' << str.gsub(/[\\\"]/o, "\\\1") << '"'
  end

  # So utility functions are accessible as Rack::REST::Utils.foo as well as via including the module
  extend self
end
