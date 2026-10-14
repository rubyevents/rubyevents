# frozen_string_literal: true

module Static
  class Sponsor < Yerba::Record::Base
    self.glob = "**/sponsors.yml"
    self.base_path = Rails.root.join("data")
    self.flatten = true

    schema SponsorsSchema
  end
end
