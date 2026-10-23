# frozen_string_literal: true

module Static
  class Involvement < Yerba::Record::Base
    self.path = "data/:series_id/:event_id/involvements.yml"
    self.flatten = true

    schema do
      string :name, description: "Role or involvement type (e.g., 'Organizer', 'Program Committee member')"
      array :users, of: :string, description: "Person names involved in this role", required: false
      array :organisations, of: :string, description: "Organization names involved in this role", required: false
    end

    belongs_to :event
    has_one :series, through: :event

    references :users, class_name: "Static::Speaker"
  end
end
