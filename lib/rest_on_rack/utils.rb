# These are various utility functions which aid the conversion back and forth between HTTP syntax and the more abstracted ruby representations we use.
module Rack::REST::Utils
  def self.path_to_identifier_components(path)
    path.sub(/^\//,'').split('/').map {|component| Rack::Utils.unescape(component)}
  end

  def self.identifier_components_to_path(components)
    '/' + components.map {|component| Rack::Utils.escape(component)}.join('/')
  end

  def self.uri(request, path='/')
    scheme = request.scheme; port = request.port
    url = "#{scheme}://#{request.host}"
    url << ":#{port}" if (scheme == "https" && port != 443) || (scheme == "http" && port != 80)
    url << path
  end

  def self.identifier_components_to_uri(request, components)
    uri(request, identifier_components_to_path(components))
  end

  def self.quote(str)
    '"' << str.gsub(/[\\\"]/o, "\\\1") << '"'
  end
end
