class Talk::StaticID
  PLACEHOLDER_SPEAKER = "TODO"
  DEFAULT_KIND = "talk"

  def self.generate(event_slug:, title:, speakers: [], kind: nil)
    kind = (kind.to_s == DEFAULT_KIND) ? "" : kind.to_s.dasherize
    speakers = Array(speakers).map(&:to_s).reject { |name| name.blank? || name == PLACEHOLDER_SPEAKER }
    title = title.to_s.parameterize

    if speakers.length.between?(1, 2)
      id_from(*speakers, kind, event_slug)
    elsif title.include? kind
      id_from(title, event_slug)
    else
      id_from(kind, title, event_slug)
    end
  end

  def self.id_from(*parts)
    parts.map { |part| part.to_s.parameterize }.reject(&:blank?).join("-")
  end
end
