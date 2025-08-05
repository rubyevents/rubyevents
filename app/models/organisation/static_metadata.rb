# -*- SkipSchemaAnnotations

class Organisation::StaticMetadata < ActiveRecord::AssociatedObject
  def ended?
    static_repository&.ended || false
  end

  private

  def static_repository
    @static_repository ||= Static::Organisation.find_by(slug: organisation.slug)
  end
end
