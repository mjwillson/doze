module Doze::Resource

  # URIs and identity

  # You would typically set @uri in your constructor; resources don't have to have a URI, but certain parts of the framework require a URI
  # in order to create links to the object for Location headers, links etc.
  # Also see Router (and note that a Resource can also act as a Router for its subresources)

  # The URI path of this resource.
  # #uri= may be used by propagate_static_routes when a resource which is also a router, is statically routed to.
  # you can private :uri= if you don't want it writeable, however.
  attr_accessor :uri

  # Wraps up the URI path of this resource as a URI::Generic
  def uri_object
    URI::Generic.build(:path => uri)
  end


  # Authorization / Authentication:
  #
  # Return true or false to allow or deny the given action on this resource for the given user (if user is nil, for the unauthenticated user).
  # If you deny an action by the unauthenticated user, this will be taken as a requirement for authentication. So eg if authentication is all you require,
  # you could just return !user.nil?
  #
  # method will be one of:
  #  * get, put, post, delete, or some other recognized_method where we supports_method?
  #
  # user will be the authenticated user, or nil if there is no authenticated user. The exact nature of the user object will depend on the middleware used
  # to do authentication.
  def authorize(user, method)
    true
  end

  # You can return false here to make a resource instance act like it doesn't exist.
  #
  # You could use this if it's more convenient to have a router create an instance representing a potentially-extant resource,
  # and to have the actual existence test run on the instance.
  #
  # Or you can use it if you want to support certain non-get methods on a resource, but appear non-existent in response to get requests.
  def exists?
    true
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
  #   * A single entity representation, in the form of an instance of Doze::Entity
  #
  #   * An array of multiple entity representations, instances of Doze::Entity with different media_types and/or languages.
  #     Content negotiation may be used to select an appropriate entity from the list.
  #     NB: if you return multiple entities we recommend using 'lazy' Doze::Entity instances constructed with a block -
  #         this way the entity data will not need to be generated for entities which aren't selected by content negotiation.
  #
  #   * A resource representation, in the form of a Doze::Resource with a URI
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
  def delete_resource
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
  #   * A Doze::Resource with identifier_components, which will be taken as a newly-created resource.
  #     This is what we're recommending as the primary intended semantics for post.
  #   * nil to indicate success without exposing a resulting resource
  #   * A Doze::Resource without identifier_components, which will be taken to be a returned description of the results of some arbitrary operation performed
  #     (see discouragement above)
  #   * A Doze::Entity, which will be taken to be a returned description of the results of some arbitrary operation performed
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
end
