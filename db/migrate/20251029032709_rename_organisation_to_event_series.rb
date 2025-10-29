class RenameOrganisationToEventSeries < ActiveRecord::Migration[8.1]
  def change
    rename_table :organisations, :event_series
    rename_column :events, :organisation_id, :event_series_id
  end
end
