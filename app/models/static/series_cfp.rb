# frozen_string_literal: true

module Static
  # The call for proposals of a whole series, like a meetup group's always-open CFP, in data/{series}/cfp.yml.
  class SeriesCFP < Yerba::Record::Base
    self.path = "data/*parent_path/:event_series_id/cfp.yml"
    self.sibling_file = "series.yml"
    self.flatten = true

    schema CFPSchema

    belongs_to :event_series
  end
end
