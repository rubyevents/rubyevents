class ChangeYouTubeChannelNameNullableOnEventSeries < ActiveRecord::Migration[8.1]
  def change
    change_column_null :event_series, :youtube_channel_name, true
  end
end
