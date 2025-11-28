class RemoveUrlFieldsFromSponsors < ActiveRecord::Migration[8.0]
  def change
    remove_column :sponsors, :logo_url, :string
    remove_column :sponsors, :banner_url, :string
  end
end
