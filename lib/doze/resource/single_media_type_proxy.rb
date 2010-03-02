# A proxy around a resource which exposes only a single representation media type.
# Intended for use with MediaTypeSpecificRoutes, eg /users/123 might route to
# SingleMediaTypeProxys at /users/123/data.json vs /users/123/data.xml
# Handy for when the client lacks control over the Accept header.
#
# The proxy also affects media type behaviour for PUT and POST.
#
# For POST: wraps any returned resource in a SingleMediaTypeProxy with the same media type
# so eg posting to /action/data.xml would return an xml representation of any response resource.
#
# For PUT: refuses to accept PUT with a media type that differs from the single media type
# specified. Eg a PUT to /foo/data.json with a XML request entity would be refused, even
# if the parent resource accepts XML, because the semantics are not that the posted entity
# would replace the resource at that url. (it might replace the resource at /foo/data.xml,
# or at /foo given semantic equivalence of the xml and json representations, but not at
# /foo/data.json given you would never be able to get the xml back from a get to /foo/data.json)
class Doze::Resource::SingleMediaTypeProxy < Doze::Resource::Proxy

  def initialize(uri, resource, media_type)
    @media_type = media_type
    super(uri, resource)
  end

  def exists?
    target.exists? && !single_entity.nil?
  end

  def get
    single_entity
  end

  def single_entity
    return @single_entity if defined?(@single_entity)
    @single_entity = begin
      result = target.get
      [*result].find {|entity| entity.media_type.subtype?(@media_type)} if result
    end
  end

  def post(*p)
    result = target.post(*p)
    case result
    when Doze::Resource
      Doze::Resource::SingleMediaTypeProxy.new(result.uri, result, @media_type)
    else
      result
    end
  end

  # It doesn't make sense to PUT /foo/data.xml with a json entity, even if you
  # could PUT /foo with the json
  def accepts_method_with_media_type?(method, entity)
    return false if method == :put && !entity.media_type.subtype?(@media_type)
    super
  end
end
