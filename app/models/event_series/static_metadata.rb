class EventSeries::StaticMetadata < ActiveRecord::AssociatedObject
  def ended?
    static_repository.try(:ended) || false
  end

  def default_country_code
    static_repository.try(:default_country_code) || nil
  end

  private

  def static_repository
    @static_repository ||= Static::EventSeries.find_by_slug(event_series.slug)
  end
end
