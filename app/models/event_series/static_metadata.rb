class EventSeries::StaticMetadata < ActiveRecord::AssociatedObject
  def ended?
    static_repository.try(:ended) || false
  end

  def default_country_code
    static_repository.try(:default_country_code) || nil
  end

  def all_youtube_channels
    static_repository&.all_youtube_channels || []
  end

  def all_youtube_channel_ids
    static_repository&.all_youtube_channel_ids || []
  end

  private

  def static_repository
    @static_repository ||= Static::EventSeries.find_by_slug(event_series.slug)
  end
end
