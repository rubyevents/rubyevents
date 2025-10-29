module Static
  class EventSeries < FrozenRecord::Base
    self.backend = Backends::FileBackend.new("event_series.yml")
    self.base_path = Rails.root.join("data")
  end
end
