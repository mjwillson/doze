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
  def has_identifier?
    !@identifier_components.nil?
  end

  # The parent resource. Having a parent resource implies that the parent's identifier_components array is a prefix of yours, hence a hierarchy of identifiers.
  # If you don't like hierarchies, you're of course welcome to have a flat identifier scheme where everything is a child of one root resource.
  # But a resource hierarchy here allows a nice generic treatment of things like collection resources.
  attr_reader :parent

  # The additional identifier components used to resolve this resource as a child of its parent
  attr_reader :additional_identifier_components

  # identifier_components given here may be strings; you can if you want convert them to appropriate ruby objects (eg an integer) provided the result
  # of to_s on the resulting object is the same as the original string.
  # if foo.resolve_subresource(bar) returns a resource, that resource must have foo as its parent, bar as its additional_identifier_components.
  def resolve_subresource(identifier_components)
    first_component, *others = *identifier_components
    resource = self.subresource(first_component) and [resource, others]
  end

  # Convenience hook to resolve a subresource by a single identifier component (the most common case)
  def subresource(identifier_component)
    nil
  end

  def put_subresource_from_identifier_components(*components)
    nil
  end

  def require_authentication?
    false
  end

  def authorize(action, user)
    true
  end

  def exists?
    true
  end

  STANDARD_RESTFUL_METHODS = ['get', 'post', 'put', 'delete']
  # for every method here there should be a supports_foo?

  # Recognizing a method just means, 'we know what you mean here'. Whether this resource supports_method? it is another question, which
  # will only be asked if the method is recognized.
  # This is to distinguish 'method not implemented' from 'method not allowed'. Also ensures that supports_method doesn't get passed
  # anything stupid and/or dangerous from user input.
  def recognizes_method?(method)
    STANDARD_RESTFUL_METHODS.include?(method)
  end

  # A convenience which some libraries add to Kernel
  def try(method, *args, &block)
    send(method, *args, &block) if respond_to?(method)
  end

  def supports_method?(method)
    try("supports_#{method}?")
  end

  def supports_get?
    true
  end

  def supports_put?
    false
  end

  def supports_post?
    false
  end

  def supports_delete?
    false
  end

  def supported_methods
    STANDARD_RESTFUL_METHODS.select {|method| supports_method?(method)}
  end

  # Content negotiation and getting resource representation(s)

  def supports_media_type_negotiation?
    false
  end

  def supports_language_negotiation?
    false
  end

  # GET methods
  #
  # To support get, you must override one of get_resource_representation, get_entity_representations or get_entity_representation.
  #
  # get_resource_representation will be called first to get a representation resource to redirect to; if it returns nil,
  # get_entity_representation(s) will be called.
  #
  # All get methods should be safe, that is, not have any side-effects visible to the caller. This also implies idempotency (which is weaker).
  # If you wish to indicate that the resource is missing, return false from exists?
  #
  # get_entity_representations:
  # Called when content negotiation (media_type or language) is supported and has been requested.
  # Should return an array of Rack::REST::Entity, each consisting of an available representation entity.
  # The appropriate one will be chosen and used.
  #
  # If you return multiple entities, we recommend you use 'lazy' Rack::REST::Entity instances constructed
  # with a block, to avoid the cost of generating each available response entity upfront.
  #
  # By default this will return an array of just the one representation returned from get_entity_representation.
  def get_entity_representations
    [get_entity_representation].compact
  end

  # get_entity_representation: called to get a single entity representation of the resource. It may be used when content
  # negotiation is not supported or requested.
  #
  # To support get, you must override one of get_entity_representations or get_entity_representation.
  # By default this will pick the first entity from get_entity_representations.
  def get_entity_representation
    get_entity_representations.first
  end

  # You have the opportunity to return another resource which may taken as a representation of this one. This will be used in preference over
  # entity_representation to respond to a get.
  #
  # A returned resource must have an identifier; in the case of HTTP this would lead to a redirect to that resource.
  def get_resource_representation
    nil
  end


  # Called to update the entirity of the this resource to the resource represented by the given representation entity.
  # entity will be a new entity representation whose media_type has been okayed by accepts_put_with_media_type?
  #
  # Should be idempotent; Subsequent to a successful put, the following should hold:
  #   * get should return the updated entity representation (or an alternative representation with the same resource-level semantics)
  #   * parent.resolve_subresource(additional_identifier_components) should return a resource for which the same holds.
  #
  # Need not return anything; success is assumed unless an error is raised. (or: should we have this return true/false?)
  def put(entity)
    nil
  end

  # Called to delete this resource.
  #
  # Should be idempotent. Subsequent to a successful delete, the following should hold:
  #  * exists? should return false, or get should return nil, or both
  #  * parent.resolve_subresource(additional_identifier_components) should return nil, or return a resource which "doesn't exist" in the same sense as above.
  #
  # Need not return anything; success is assumed unless an error is raised. (or: should we have this return true/false?)
  def delete
    nil
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
  # entity will be a entity whose media_type has been okayed by accepts_post_with_media_type?
  #
  # Does not need to be idempotent or safe, and should not be assumed to be.
  #
  # May return:
  #   * A Rack::REST::Resource with identifier_components, which will be taken as a newly-created resource.
  #     This is what we're recommending as the primary intended semantics for post.
  #   * nil to indicate success without exposing a resulting resource
  #   * A Rack::REST::Resource without identifier_components, which will be taken to be a returned description of the results of some arbitrary operation performed
  #     (see discouragement above)
  #   * A Rack::REST::Entity, which will be taken to be a returned description of the results of some arbitrary operation performed
  #     (this one even more discouraged, but there if you need a quick way to make an arbitrary fixed response)
  def post(entity)
    nil
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
  # entity will be nil, or an entity whose media_type has been okayed by accepts_method_with_media_type?(method_name, ..)
  #
  # Return options are the same as for post, as are their interpretations, with the exception that a resource returned will not be assumed to be newly-created.
  # (we're taking the stance that you should be using post or put for creation of new resources).
  #
  # By default it'll call a ruby method of the same name to call, as already happens for post/put/delete. This is safe as recognizes_method? and supports_method?
  # will have been checked first.
  def other_method(method_name, entity=nil)
    try(method_name, entity)
  end

  def accepts_method_with_media_type?(resource_method, media_type)
    try("accepts_#{resource_method}_with_media_type?", media_type)
  end

  def accepts_put_with_media_type?(media_type)
    false
  end

  def accepts_post_with_media_type?(media_type)
    false
  end



  # Caching and modification-related metadata

  # May return a Time object inidicating the last modification date, or nil if not known
  def last_modified
    nil
  end

  # nil = no explicit policy, false = explicitly no caching, true = caching yes please
  def cacheable?
    nil
  end

  # false here (when cacheable? is true) implies that private caching only is desired.
  def publicly_cacheable?
    cacheable?
  end

  # Integer seconds, or nil for no explicitly-specified expiry period. Will only be checked if cacheable? is true.
  # todo: a means to specify the equivalent of 'must-revalidate'
  def cache_expiry_period
    nil
  end

  # You can override public_cache_expiry_period to specify a longer or shorter period for public caches.
  # Otherwise assumed same as general cache_expiry_period.
  def public_cache_expiry_period
    nil
  end




  # Put to missing subresource

  # Equivalent to supports_put?, but is given child_identifier_components for the proposed subresource
  def supports_put_to_missing_subresource?(child_identifier_components)
    false
  end

  # Equivalent to accepts_put_with_media_type?, but is given child_identifier_components for the proposed subresource
  def accepts_put_to_missing_subresource_with_media_type?(child_identifier_components, media_type)
    false
  end

  # Called to create a new subresource with the identifier given by child_identifier_components ontop of the identifier_components of self.
  # The new resource created must have the given entity as one of its representations (or a resource-level semantic equivalent).
  # Entity will be a new entity representation whose media_type has been okayed by accepts_put_to_missing_subresource_with_media_type?
  #
  # Subsequent to a successful put_to_missing_subresource, the following should hold:
  #   * resolve_subresource(child_identifier_components) should return the new subresource
  #
  # Need not return anything; success is assumed unless an error is raised. (or: should we have this return true/false?)
  def put_to_missing_subresource(child_identifier_components, entity)
    nil
  end


  # Resource-level Range requests

  # May return a list of supported resource-level unit types, eg 'items', 'pages'.
  #
  # Note that this interface is not intended to be used when the range depends on the particular representation entity selected
  # (eg for byte-ranges). TODO: add a representation-entity-specific range API which is called after content negotiation.
  #
  # If there are supported_range_units, then calls to get may be passed an instance of Rack::REST::Range.
  # get must then return the whole collection (if range not given) or just the range specified (if given)
  # or nil (if the range specified turns out to be unsatisfiable).
  def supported_range_units
    nil
  end

  # Where range units are supported and a range request is made, one of these will be called instead of get_entity_representation(s).
  # See get_entity_representations
  def get_entity_representations_with_range(range)
    [get_entity_representation_with_range(range)].compact
  end

  # See get_entity_representations
  def get_entity_representation_with_range(range)
    get_entity_representations_with_range(range).first
  end

  # Since some of these may depend on the particular representation entity negotiated, a negotiator may be passed to them as to get.

  # Given a supported unit type, should return an integer for how many of that unit exist in this resource.
  # May return nil if the length is not known upfront or you don't wish to calculate it upfront; in this case
  # length_of_range_satisfiable will be called to establish how much of the range is able to be satisfied.
  def range_length(units, negotiator=nil)
    nil
  end

  # Only called if range_length is not known. Given a Rack::REST::Range, return the length of that range
  # which you will be able to satisfy. Something between 0 and range.length. You could use this eg to 'suck it and see'
  # via an sql query with an offset and limit, without asking for the total count.
  def length_of_range_satisfiable(range, negotiator=nil)
    nil
  end

  # Passed a Rack::REST::Range, your chance to reject it outright for perfomance or other arbitrary reasons (like, eg, too long, too big an offset).
  # Note that you don't need to check whether it's within the total length of your collection; you should define range_length
  # so that this check can be performed separately.
  def range_acceptable?(range, negotiator=nil)
    true
  end
end
