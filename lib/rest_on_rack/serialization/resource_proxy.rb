require 'rest_on_rack/serialization/resource'
require 'rest_on_rack/resource/proxy'

class Rack::REST::Serialization::ResourceProxy < Rack::REST::Resource::Proxy
  include Rack::REST::Serialization::Resource

  proxied_methods = Rack::REST::Serialization::Resource.public_instance_methods(true) - ['get', 'put', 'post'] - self.public_instance_methods(false)
  proxied_methods.each do |method|
    module_eval("def #{method}(*args, &block); @target.__send__(:#{method}, *args, &block); end", __FILE__, __LINE__)
  end
end
