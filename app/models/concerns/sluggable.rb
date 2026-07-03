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

    self.slug = slug.presence || I18n.transliterate(source_value.downcase).parameterize

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
