require 'rest_on_rack/request'

module Rack::REST::Resource

  # You can call this within your constructor, if you want the resource to know about its parent scope and/or resource identifier (via identifier_components).
  # You are allowed to have a resource without identifier_components in certain circumstances, although this limits how the resource can be exposed.
  #   eg initialize_resource(users_resource, [1234])     for a subresource of a users resource, identifier would map to URI (say) /users/1234
  #      initialize_resource(nil, ['foo', 'bar', 'baz']) for a parentless root resource with a hard-coded identifier that'd map to URI /foo/bar/baz
  #      initialize_resource(nil, [])                    for a parentless root resource with a hard-coded identifier that'd map to URI /
  #      initialize_resource()                           for a resource without any identifier (effectively a no-op)
  # Where a parent is set, parent.resolve_subresource(additional_identifier_components) must return self.
  # Where a parent is not set and identifier_components are specified, they should reflect the identifier at which the resource is (to be) deployed.
  def initialize_resource(parent=nil, identifier_components=nil)
    if parent
      @parent = parent
      @additional_identifier_components = identifier_components
      parent_identifier_components = @parent.identifier_components
      @identifier_components = parent_identifier_components + identifier_components if parent_identifier_components
    else
      @identifier_components = identifier_components
    end
  end

  private :initialize_resource

  # identifier_components is an array of objects representing components of this object's resource identifier.
  # This is essentially an abstraction of the notion of path components within a URI; the code exposing the resource will
  # handle translating these to and from protocol-specific identifier format (a URI in HTTP). In particular this means you don't need to worry
  # about encoding issues, just treat these as arbitrary strings.
  #
  # (In fact if you want to, you can specify an arbitrary ruby object, eg an integer, as an identifier component, but it must support to_s,
  #  and resolve_subresource must be prepared to accept the string version of it)
  attr_reader :identifier_components

  # A resource has_identifier? if identifier_components are set. A resource which has_identifier? can be referred to
  def has_identifier?; !@identifier_components.nil?; end

  # The parent resource. Having a parent resource implies that the parent's identifier_components array is a prefix of yours, hence a hierarchy of identifiers.
  # If you don't like hierarchies, you're of course welcome to have a flat identifier scheme where everything is a child of one root resource.
  # But a resource hierarchy here allows a nice generic treatment of things like collection resources.
  attr_reader :parent

  # The additional identifier components used to resolve this resource as a child of its parent
  attr_reader :additional_identifier_components

  # identifier_components given here may be strings; you can if you want convert them to appropriate ruby objects (eg an integer) provided the result
  # of to_s on the resulting object is the same as the original string.
  # if foo.resolve_subresource(bar) returns a resource, that resource must have foo as its parent, bar as its additional_identifier_components.
  def resolve_subresource(identifier_components, for_method='get')
    first_component, *others = *identifier_components
    resource = self.subresource(first_component) and [resource, others]
  end

  # Convenience hook to resolve a subresource by a single identifier component (the most common case)
  def subresource(identifier_component)
  end

  def put_subresource_from_identifier_components(*components)
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

  def supports_method_on_missing_subresource?(method, identifier_components)
    supports = :"supports_#{method}"
    respond_to?(supports) && send(supports, identifier_components)
  end

  def supported_methods_on_missing_subresource(identifier_components)
    STANDARD_RESTFUL_METHODS.filter {|method| supports_method_on_missing_subresource?(method, identifier_components)}
  end

  def supports_get_on_missing_subresource?(identifier_components);    false; end
  def supports_put_on_missing_subresource?(identifier_components);    false; end
  def supports_post_on_missing_subresource?(identifier_components);   false; end
  def supports_delete_on_missing_subresource?(identifier_components); false; end

  # Methods to help with negotiation of selected representation

  def supports_media_type_negotiation?; false; end
  def supports_language_negotiation?;   false; end

  # Should return a Rack::REST::Representation, or nil if no suitable representation is available.
  # If supports_language_negotiation? or supports_media_type_negotiation? are true, you will be passed a Rack::REST::Negotiator (see the docs on this class);
  # if you return nil it will then be intepreted as a failure to negotiate a suitable entity representation
  def entity_representation(negotiator=nil)
  end

  # You have the opportunity to return another resource which may taken as a representation of this one. This will take preference over
  # an entity_representation response (although you can override get)
  #
  # A returned resource must have an identifier; in the case of HTTP this would lead to a redirect to that resource.
  def resource_representation
  end

  # A key method to override; preferred_representation_metadata will be one of metadata_for_available_entity_representations, or nil.
  #
  # Should be idempotent, and safe ie not have any side-effects visible to the caller.
  #
  # May return:
  #   * A Rack::REST::Representation as a representation entity of this resource
  #   * Another Rack::REST::Resource as a representation resource of this resource (would correspond to a redirect in HTTP)
  #   * nil, indicating that the resource is missing (although exists? is preferred if you wish to indicate this as it works with methods other than get)
  #
  # The default implementation will call resource_representation to get another resource which may taken as a representation of this one
  # failing that it'll call entity_representation to get an appropriate Rack::REST::Representation.
  #
  # negotiator: may be an instance of Rack::REST::Negotiator; see entity_representation
  def get(negotiator=nil)
    resource_representation || entity_representation(negotiator)
  end

  # Called to update the entirity of the this resource to the resource represented by the given representation entity.
  # Representation will be a entity representation whose media_type has been okayed by accepts_put_with_media_type?
  #
  # Should be idempotent; Subsequent to a successful put, the following should hold:
  #   * get should return the updated representation (or an alternative representation with the same resource-level semantics)
  #   * parent.resolve_subresource(additional_identifier_components) should return a resource for which the same holds.
  #
  # Need not return anything; success is assumed unless an error is raised. (or: should we have this return true/false?)
  def put(representation)
  end

  # Called to delete this resource.
  #
  # Should be idempotent. Subsequent to a successful delete, the following should hold:
  #  * exists? should return false, or get should return nil, or both
  #  * parent.resolve_subresource(additional_identifier_components) should return nil, or return a resource which "doesn't exist" in the same sense as above.
  #
  # Need not return anything; success is assumed unless an error is raised. (or: should we have this return true/false?)
  def delete
  end

  # Intended to be called in order to:
  #  * Allocate an identifier for a new subresource, and create this subresource, based on the representation entity if given.
  #    (Note: use put_to_missing_subresource instead if you know the desired identifier)
  #  * Create a new interal resource which isn't exposed to the caller (eg, log some data)
  #
  # May also be used for legacy reasons for some other wider purposes:
  #  * To annotate, append to or otherwise modify the current resource based on instructions contained in the given representation entity,
  #    potentially returning an anonymous resource describing the results
  #  * Otherwise process instructions contained in the given representation entity, returning an anonymous resource describing the results
  # Note: these uses are a bit of a catch-all, not very REST-ful, and discouraged, see other_method.
  #
  # Representation will be a entity representation whose media_type has been okayed by accepts_post_with_media_type?
  #
  # Does not need to be idempotent or safe, and should not be assumed to be.
  #
  # May return:
  #   * A Rack::REST::Resource with identifier_components, which will be taken as a newly-created resource.
  #     This is what we're recommending as the primary intended semantics for post.
  #   * nil to indicate success without exposing a resulting resource
  #   * A Rack::REST::Resource without identifier_components, which will be taken to be a returned description of the results of some arbitrary operation performed
  #     (see discouragement above)
  #   * A Rack::REST::Representation, which will be taken to be a returned description of the results of some arbitrary operation performed
  #     (this one even more discouraged, but there if you need a quick way to make an arbitrary fixed response)
  def post(representation)
  end

  # This allows you to accept methods other than the standard get/put/post/delete from HTTP. When the resource is exposed over a protocol (or requested by a client)
  # which doesn't support custom methods, some form of tunnelling will be used, typically ontop of POST.
  #
  # Semantics are up to you, but should not, and will not, be assumed to be idempotent or safe by any generic middleware.
  #
  # When should you consider using a custom method? as I understand it, the REST philosophy is that this is valid and to be encouraged if and only if:
  #  * Your proposed method has clearly-defined semantics which have the potential to apply generically to a wide variety of resources and media types
  #  * It doesn't overlap with the semantics of existing methods in a confusing or redundant way (exception: it may be used to replace legacy uses of post
  #    as described; see eg patch)
  #  * Requests with the method can safely be forwarded around by middleware which don't know anything about their semantics
  #  * You've given due consideration to the alternative: rephrasing the problem in terms of standard methods acting on a different resource structure.
  #    And you concluded that this would be significantly less elegant / would add excessive conceptual (or implementation) overhead
  #  * Ideally, some attempt has been made to standardize it
  # The proposed 'patch' method (for selective update of a resource by a diff-like media type) is a good example of something which meets these criterea.
  # http://greenbytes.de/tech/webdav/draft-dusseault-http-patch-11.html
  #
  # Representation will be nil, or an entity representation whose media_type has been okayed by accepts_method_with_media_type?(method_name, ..)
  #
  # Return options are the same as for post, as are their interpretations, with the exception that a resource returned will not be assumed to be newly-created.
  # (we're taking the stance that you should be using post or put for creation of new resources)
  def other_method(method_name, representation=nil)
  end

  def accepts_method_with_media_type?(resource_method, media_type)
    method = :"accepts_#{resource_method}_with_media_type"
    respond_to?(method) && send(method, media_type)
  end

  def accepts_put_with_media_type?(media_type); false; end
  def accepts_post_with_media_type?(media_type); false; end

  # Modification date

  # May return a Time object inidicating the last modification date, or nil if not known
  def last_modified
  end
end
