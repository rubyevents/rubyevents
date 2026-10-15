# frozen_string_literal: true

module Static
  class CFP < Yerba::Record::Base
    self.glob = "**/cfp.yml"
    self.base_path = Rails.root.join("data")
    self.flatten = true

    schema CFPSchema

    belongs_to :event
  end
end
