module Sluggable
  extend ActiveSupport::Concern

  included do
    before_validation :set_slug, on: :create
    validates :slug, presence: true
    validates :slug, uniqueness: true
  end

  def to_param
    slug
  end

  private

  def set_slug
    source_value = send(slug_source)
    return if source_value.blank?
    return if slug.present?

    transliterated = source_value.romaji.to_slug.transliterate.normalize.to_s
    transliterated = transliterated.gsub(/[^\x00-\x7F]/, "").strip

    if transliterated.blank?
      Rails.logger.warn("[Sluggable] Could not generate slug for #{self.class.name} with #{slug_source}: #{source_value.inspect}. Please set the slug manually.")
      return
    end

    self.slug = transliterated

    # if slug is already taken, add a random string to the end
    if self.class.exists?(slug: slug) && self.class.auto_suffix_on_collision
      self.slug = "#{slug}-#{SecureRandom.hex(4)}"
    end
  end

  def slug_source
    self.class.slug_source
  end

  class_methods do
    attr_reader :slug_source, :auto_suffix_on_collision

    def configure_slug(attribute:, auto_suffix_on_collision: false)
      @auto_suffix_on_collision = auto_suffix_on_collision
      @slug_source = attribute.to_sym
    end
  end
end
