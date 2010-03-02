#
module Doze::Resource::MediaTypeSpecificRoutes
  include Doze::Router

  def self.included(mod)
    return unless mod.is_a?(Class) # if included in another module, its .included should call this one
    raise "Doze::Resource::MediaTypeSpecificRoutes: only suitable for mixing into a Doze::Resource" unless mod < Doze::Resource

    Doze::Router.included(mod)

    mod.route "/data.{extension}", :name => 'specific_media_type', :regexps => {:extension => /[a-z0-9_]+/} do |router, uri, params|
      media_type = Doze::MediaType::BY_EXTENSION[params[:extension]]
      media_type && router.media_type_specific_proxy(media_type, uri)
    end
  end

  def media_type_specific_proxy(media_type, uri=nil)
    unless uri
      extension = media_type.extension or raise "specify a media_type with an extension, or specify the uri"
      uri = expand_route_template('specific_media_type', :extension => extension)
    end
    Doze::Resource::SingleMediaTypeProxy.new(uri, self, media_type)
  end
end
