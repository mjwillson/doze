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

  # Authorization / Authentication:
  #
  # Return true or false to allow or deny the given action on this resource for the given user (if user is nil, for the unauthenticated user).
  # If you deny an action by the unauthenticated user, this will be taken as a requirement for authentication. So eg if authentication is all you require,
  # you could just return !user.nil?
  #
  # action will be one of:
  #  * resolve_subresource
  #  * get, put, post, delete, or some other recognized_method where we supports_method?
  #  * put_on_subresource, post_on_subresource, delete_on_subresource, or some other recognized_method where we supports_method_on_subresource?
  #
  # user will be the authenticated user, or nil if there is no authenticated user. The exact nature of the user object will depend on the middleware used to do authentication.
  #
  # the reason resolve_subresource is included alongside the request methods as an action for authorization is so that you can easily implement simple blanket
  # authorization rules for all subresources of a given resource.
  def authorize(user, action)
    true
  end

  # You can return false here to make a resource instance act like it doesn't exist, as an alternative to returning nil from resolve_subresource on the parent.
  #
  # You could use this if it's more convenient to have resolve_subresource create an instance representing the potentially-extant resource,
  # and to have the existence test run on the instance.
  #
  # Or you can use it if you want to support certain non-get methods on a resource, but appear non-existent in response to get requests.
  # (implementing put_on_subresource on the parent resource is available too as an alternative for implementing put on a non-existent resource)
  def exists?
    true
  end

  # Recognizing a method just means, 'we know what you mean here'. Whether this resource supports_method? it is another question, which
  # will only be asked only for recognized methods.
  # This is to distinguish 'method not implemented' from 'method not allowed'. Also ensures that supports_method doesn't get passed
  # anything stupid and/or dangerous from user input.
  def recognized_methods
    ['get', 'post', 'put', 'delete']
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


  # Called to obtain one or more representations of the resource.
  #
  # Should be safe, that is, not have any side-effects visible to the caller. This also implies idempotency (which is weaker).
  #
  # You may return either:
  #
  #   * A single entity representation, in the form of an instance of Rack::REST::Entity
  #
  #   * An array of multiple entity representations, instances of Rack::REST::Entity with different media_types and/or languages.
  #     Content negotiation may be used to select an appropriate entity from the list.
  #     NB: if you return multiple entities we recommend using 'lazy' Rack::REST::Entity instances constructed with a block -
  #         this way the entity data will not need to be generated for entities which aren't selected by content negotiation.
  #
  #   * A resource representation, in the form of a Rack::REST::Resource which has_identifier?
  #     This would correspond to a redirect in HTTP.
  #
  # If you wish to indicate that the resource is missing, return false from exists?
  def get
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
  #    (Note: use put_on_subresource instead if you know the desired identifier)
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
  # By default it'll call a ruby method of the same name to call, as already happens for post/put/delete.
  def other_method(method_name, entity=nil)
    try(method_name, entity)
  end

  # Called to determine whether the request entity is of a suitable media type for the method in question (eg for a put or a post).
  # The entity itself is passed in. If you return false, the method will never be called; if true then the method may be called with the entity.
  def accepts_method_with_media_type?(resource_method, entity)
    try("accepts_#{resource_method}_with_media_type?", entity)
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




  # "method on subresource" hooks for parent resources
  #
  # Why is this functionality offered? main use cases:
  # * a put to a missing subresource
  #    - because the parent needs the ability to handle this when the subresource doesn't yet exist
  # * a put which replaces an existing child resource
  #    - because sometimes it'll be more convenient for the parent resource to handle replacing its child, rather
  #      than the child 'replacing' itself.
  # * a delete which removes a child resource
  #    - again sometimes it'll be more convenient for the parent to handle removing a child, than for the child to remove
  #      itself
  #
  # How this works: first of all resolve_subresource is used to resolve the identifier as far as possible.
  # If remaining identifier components are left over, these are interpreted as referring to a missing subresource.
  # Each parent resource in turn is then given an opportunity to support the method on a subresource, and passed
  # the remaining identifier components required at that level to refer to the child subresource in question.
  #
  # If the resource is resolved fully but doesn't directly support the method in question, again each parent
  # resource in turn is then given an opportunity to support the method on a subresource, and passed
  # the remaining identifier components required at that level to refer to the child subresource in question.
  #
  # Only non-get methods may be supported on a subresource.
  # If you support a method on a subresource, you need to define a corresponding #{method}_on_subresource method, eg:
  # * put_on_subresource(child_identifier_components, entity)
  # * post_on_subresource(child_identifier_components, entity)
  # * delete_on_subresource(child_identifier_components)
  def supports_method_on_subresource?(child_identifier_components, method)
    try("supports_#{method}_on_subresource?", child_identifier_components)
  end

  def accepts_method_on_subresource_with_media_type?(child_identifier_components, method, entity)
    try("accepts_#{method}_on_subresource_with_media_type?", child_identifier_components, entity)
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

  # Where range units are supported and a range request is made, this will be called with a range, instead of get
  # Interface otherwise the same as for get.
  def get_with_range(range)
    nil
  end

  # Since some of these may depend on the particular representation entity negotiated, a negotiator may be passed to them as to get.

  # Given a supported unit type, should return an integer for how many of that unit exist in this resource.
  # May return nil if the length is not known upfront or you don't wish to calculate it upfront; in this case
  # length_of_range_satisfiable will be called to establish how much of the range is able to be satisfied.
  def range_length(units)
    nil
  end

  # Only called if range_length is not known. Given a Rack::REST::Range, return the length of that range
  # which you will be able to satisfy. Something between 0 and range.length. You could use this eg to 'suck it and see'
  # via an sql query with an offset and limit, without asking for the total count.
  def length_of_range_satisfiable(range)
    nil
  end

  # Passed a Rack::REST::Range, your chance to reject it outright for perfomance or other arbitrary reasons (like, eg, too long, too big an offset).
  # Note that you don't need to check whether it's within the total length of your collection; you should define range_length
  # so that this check can be performed separately.
  def range_acceptable?(range)
    true
  end
end
