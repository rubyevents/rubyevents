class RemoveCFPFieldsFromEvents < ActiveRecord::Migration[8.1]
  def change
    remove_column :events, :cfp_link, :string
    remove_column :events, :cfp_open_date, :date
    remove_column :events, :cfp_close_date, :date
  end
end
