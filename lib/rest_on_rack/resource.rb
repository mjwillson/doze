require 'rest_on_rack/request'

module Rack::REST::Resource
  def resolve_subresource(path_components, for_method='get')
    first_component, *others = *path_components
    resource = self.subresource(first_component) and [resource, others]
  end

  def subresource(path_component)
  end

  def put_subresource_from_path_components(*components)
  end

  def require_authentication?
    false
  end

  def authorize(action, user)
    true
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

  def supports_method_on_missing_subresource?(method, path_components)
    supports = :"supports_#{method}"
    respond_to?(supports) && send(supports, path_components)
  end

  def supported_methods_on_missing_subresource(path_components)
    STANDARD_RESTFUL_METHODS.filter {|method| supports_method_on_missing_subresource?(method, path_components)}
  end

  def supports_get_on_missing_subresource?(path_components);    false; end
  def supports_put_on_missing_subresource?(path_components);    false; end
  def supports_post_on_missing_subresource?(path_components);   false; end
  def supports_delete_on_missing_subresource?(path_components); false; end

  # Methods to help with negotiation of selected representation

  def available_media_types
    media_type ? [media_type] : []
  end

  # convenience hook to define a single available media_type
  def media_type
  end

  # An available language of nil indicates that representations exist, but with unknown or no language
  def available_languages
    [language]
  end

  # Convenience hook to define a single available language (nil = unknown / no language is available)
  def language
  end

  # override if only particular media_type / language combinations exist; default implementation assumes that all combinations are available
  def available_representations
    available_media_types.map {|media_type| available_languages.map {|language| :media_type => media_type, :language => language}}.flatten
  end

  # A key method to override; metadata will be (as above) a hash with keys :media_type and :language, and will always be one of those
  # returned from available_representations. If you only define one available_representation you can of course safely ignore this parameter.
  # Should return a Rack::REST::Representation
  def get_representation(metadata)
  end

  def accepts_method_with_media_type?(resource_method, media_type)
    method = :"accepts_#{resource_method}_with_media_type"
    respond_to?(method) && send(method, media_type)
  end

  def accepts_put_with_media_type?(media_type); false; end
  def accepts_post_with_media_type?(media_type); false; end
end
