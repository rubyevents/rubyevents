class AddCallForPapersToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :cfp_link, :string
    add_column :events, :cfp_open_date, :date
    add_column :events, :cfp_close_date, :date
  end
end
