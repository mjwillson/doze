# A negotiator is passed to a resource on behalf of a request, and will choose the entity it prefers from options offered to it by the resource.
# You can ask it to give you a quality value, or to choose from a list of options. It'll choose from media_types, languages, or combinations of the two.
class Rack::REST::Negotiator
  def initialize(request, ignore_unacceptable_accepts=false)
    accept_header = request.env['HTTP_ACCEPT']
    @ignore_unacceptable_accepts = ignore_unacceptable_accepts
    @media_type_criterea = if accept_header
      parse_accept_header(accept_header) {|range| matcher_from_media_range(range)}.sort_by {|matcher,specificity,q| -specificity}
    else
      [[Object, 0, 1.0]]
    end

    accept_language_header = request.env['HTTP_ACCEPT_LANGUAGE']
    @language_criterea = if accept_language_header
      parse_accept_header(accept_language_header) {|range| matcher_from_language_range(range)}.sort_by {|matcher,specificity,q| -specificity} + [[nil, 0, 0.001]]
      # When language_criterea are given, we allow a low-specificity tiny-but-nonzero match for a language of 'nil', ie entities with no
      # language, even though the accept header may appear to require a particular language. Because it makes no sense to apply Accept-Language
      # criterea to resources whose representations aren't language-specific.
    else
      [[Object, 0, 1.0]]
    end
  end

  def media_type_quality(media_type)
    @media_type_criterea.each {|matcher,specificity,quality| return quality if media_type.all_applicable_names.any? {|name| matcher === name}}; 0
  end

  def language_quality(language)
    @language_criterea.each {|matcher,specificity,quality| return quality if matcher === language}; 0
  end

  # Combined quality value for a (media_type, language) pair
  def quality(media_type, language)
    media_type_quality(media_type)*language_quality(language)
  end

  # Choose from a list of Rack::REST::Entity
  def choose_entity(entities)
    max_by_non_zero(entities) {|a| quality(a.media_type, a.language)}
  end

  private
    # Given an http-style media-range, language-range, charset-range etc string, return a ruby object which answers to ===(string)
    # for whether or not that string matches the range given. (note: these are useful in combination with Enumerable#grep)
    # together with a priority value for the priority of this matcher (most specific has highest priority)
    # Example input: *, text/*, text/html, en, en-gb, utf-8
    def matcher_from_media_range(range_string)
      case range_string
      when '*', '*/*'
        # Object === 'anything'
        [Object,                  0]
      when /^(.*?\/)\*$/
        # media type range eg text/*
        [/^#{Regexp.escape($1)}/, 1]
      else
        [range_string,            2]
      end
    end

    def matcher_from_language_range(range_string)
      case range_string
      when '*'
        # Object === 'anything'
        [Object,                  0]
      else
        # en matches en, en-gb, en-whatever-else-after-a-hyphen, with longer strings more specific
        [/^#{Regexp.escape(range_string)}(-|$)/, range_string.length]
      end
    end

    def parse_accept_header(accept_header_value)
      accept_header_value.split(/,\s*/).map do |part|
        /^([^\s,]+?)(?:;\s*q=(\d+(?:\.\d+)?))?$/.match(part) or next # From WEBrick via Rack
        q = ($2 || 1.0).to_f
        matcher, specificity = yield($1)
        [matcher, specificity, q]
      end.compact
    end

    def max_by_non_zero(array)
      max_quality = 0; max_item = nil
      array.each do |item|
        quality = yield(item)
        if quality > max_quality
          max_quality = quality
          max_item = item
        end
      end
      max_item || (@ignore_unacceptable_accepts && array.first)
    end
end
