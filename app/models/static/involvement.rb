# frozen_string_literal: true

module Static
  class Involvement < Yerba::Record::Base
    self.glob = "**/involvements.yml"
    self.base_path = Rails.root.join("data")
    self.flatten = true

    schema InvolvementSchema

    belongs_to :event
  end
end
