# frozen_string_literal: true

module Static
  class Involvement < Yerba::Record::Base
    self.path = "data/:series_id/:event_id/involvements.yml"
    self.flatten = true

    schema InvolvementSchema

    belongs_to :event
    has_one :series, through: :event

    references :users, class_name: "Static::Speaker"

    validates :users, "static/speaker_exists": true, on: :lint
    validates :name, presence: {message: "must be set when there are no organisations"}, unless: -> { self["organisations"].present? }
    validates_with Static::InvolvementNameValidator
  end
end
