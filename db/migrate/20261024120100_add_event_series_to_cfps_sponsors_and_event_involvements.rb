class AddEventSeriesToCfpsSponsorsAndEventInvolvements < ActiveRecord::Migration[8.2]
  def change
    %i[cfps sponsors event_involvements].each do |table|
      add_reference table, :event_series, foreign_key: true, null: true
      change_column_null table, :event_id, true
    end

    %i[sponsors event_involvements].each do |table|
      add_column table, :started_on, :date
      add_column table, :ended_on, :date
    end
  end
end
