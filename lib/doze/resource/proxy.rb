# A proxy wrapper for a resource instance, which allows you to proxy through to its resource functionality
# while potentially overriding some of it with context-sensitive behaviour.
# Unlike the proxies in the stdlib's 'delegate' library, this will satisfy is_a?(Doze::Resource) for the proxy instance.
# Also note it only proxies the Resource interface, and doesn't do any method_missing magic to proxy additional methods
# on the underlying instance. If you need this you can access the target of the proxy with #target, or use 'try',
# which has been overridden sensibly.
#
# Also note the proxy is designed to do the sensible default with a nil target, however do make sure it's doing what
# you want it to do if using with a nil target
require 'doze/resource'
class Doze::Resource::Proxy
  include Doze::Resource

  def initialize(uri, target)
    @uri = uri
    @target = target
  end

  attr_reader :target

  # Methods based around use try / respond_to? need special care when proxying:

  def try(method, *args, &block)
    if respond_to?(method)
      send(method, *args, &block)
    elsif @target.respond_to?(method)
      @target && @target.send(method, *args, &block)
    end
  end

  def supports_method?(method)
    supports_method = "supports_#{method}?"
    if respond_to?(supports_method)
      send(supports_method)
    else
      @target && @target.supports_method?(method)
    end
  end

  def other_method(method_name, entity=nil)
    if respond_to?(method_name)
      send(method_name, entity)
    else
      @target && @target.other_method(method_name, entity)
    end
  end

  def accepts_method_with_media_type?(resource_method, entity)
    method_name = "accepts_#{resource_method}_with_media_type?"
    if respond_to?(method_name)
      send(method_name, resource_method, entity)
    else
      @target && @target.accepts_method_with_media_type?(resource_method, entity)
    end
  end

  # Some methods which should return something other than nil by default for an empty target:

  def authorize(user, method)
    @target ? @target.authorize(user, method) : true
  end

  # Other methods which we can proxy generically

  proxied_methods = Doze::Resource.public_instance_methods(true) - ['uri', 'uri_object'] - self.public_instance_methods(false)
  proxied_methods.each do |method|
    module_eval("def #{method}(*args, &block); @target && @target.__send__(:#{method}, *args, &block); end", __FILE__, __LINE__)
  end
end
