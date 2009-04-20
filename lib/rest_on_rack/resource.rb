require 'rest_on_rack/request'

module Rack::REST::Resource
  def get_subresource_from_path_components(first_component, *others)
    resource = self.subresource(first_component) and [resource, others]
  end

  def get_subresource(path_component)
  end

  def put_subresource_from_path_components(*components)
  end

  def require_authentication?
    false
  end

  def authorize(action, user)
    true
  end

  def available_content_types
  end

  def representations(criteria)
  end

  def exists?; true; end

  STANDARD_RESTFUL_METHODS = ['get', 'post', 'put', 'delete']
  # for every method here there should be a supports_foo?
  def recognizes_method?(method)
    STANDARD_RESTFUL_METHODS.include?(method)
  end

  def supports_method?(method)
    supports = :"supports_#{method}"
    respond_to?(supports) && send(supports)
  end

  def supports_get?;    true;  end
  def supports_put?;    false; end
  def supports_post?;   false; end
  def supports_delete?; false; end

  def supported_methods
    STANDARD_RESTFUL_METHODS.filter {|method| supports_method?(method)}
  end
end
