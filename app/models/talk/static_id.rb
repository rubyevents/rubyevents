class Talk::StaticID
  PLACEHOLDER_SPEAKER = "TODO"

  attr_reader :event_slug

  def initialize(event_slug:, title:, speakers: [], kind: nil)
    @event_slug = event_slug
    @title = title
    @speakers = speakers
    @kind = kind
  end

  def generate
    if speakers.length.between?(1, 2)
      id_from(*speakers, kind, event_slug)
    elsif title.starts_with? kind
      id_from(title, event_slug)
    else
      id_from(kind, title, event_slug)
    end
  end

  def kind
    @kind.to_s.dasherize
  end

  def speakers
    Array(@speakers).map(&:to_s).reject { |name| name.blank? || name == PLACEHOLDER_SPEAKER }
  end

  def title
    @title.to_s.parameterize
  end

  private

  def id_from(*parts)
    parts.map { |part| part.to_s.parameterize }.reject(&:blank?).join("-")
  end
end
