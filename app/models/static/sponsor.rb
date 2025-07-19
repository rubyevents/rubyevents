module Static
  class Sponsor < FrozenRecord::Base
    self.backend = Backends::FileBackend.new("sponsors.yml")
    self.base_path = Rails.root.join("data")
  end
end