class Talk::StaticID
  PLACEHOLDER_SPEAKER = "TODO"

  attr_reader :event_slug, :title

  def initialize(event_slug:, title:, speakers: [], kind: nil)
    @event_slug = event_slug
    @title = title
    @speakers = speakers
    @kind = kind
  end

  # "firstname-lastname-event-slug" for talks with one or two speakers,
  # "kind-event-slug" (e.g. "panel-event-slug") otherwise.
  def speaker_id
    if speakers.length.between?(1, 2)
      id_from(*speakers)
    elsif kind == "talk"
      title_id
    else
      id_from(kind.dasherize)
    end
  end

  # Adds the kind, e.g. "firstname-lastname-lightning-talk-event-slug". Plain
  # talks have no kind to add, so on collisions they keep the speaker id while
  # their siblings with a kind move out of the way.
  def kind_id
    if speakers.length.between?(1, 2) && kind != "talk"
      id_from(*speakers, kind.dasherize)
    else
      speaker_id
    end
  end

  # "title-in-slug-form-event-slug", the last resort.
  def title_id
    id_from(title)
  end

  def candidates
    [speaker_id, kind_id, title_id].compact.uniq
  end

  def speakers
    Array(@speakers).map(&:to_s).reject { |name| name.blank? || name == PLACEHOLDER_SPEAKER }
  end

  def kind
    @kind.presence || Talk::Kind.from_title(title).to_s
  end

  private

  def id_from(*parts)
    base = parts.map { |part| part.to_s.parameterize }.reject(&:blank?)
    return nil if base.empty?

    [*base, event_slug].join("-")
  end
end
