# frozen_string_literal: true

module Static
  # The roles in a whole series, like a meetup group's organizers, in data/{series}/involvements.yml.
  # Names and slugs can carry a `from` and `to`.
  class SeriesInvolvement < Yerba::Record::Base
    self.path = "data/*parent_path/:event_series_id/involvements.yml"
    self.sibling_file = "series.yml"
    self.flatten = true

    schema InvolvementSchema

    belongs_to :event_series
    references :users, class_name: "Static::Speaker"
    references :organizations, class_name: "Static::Organization", key: "slug"
  end
end
