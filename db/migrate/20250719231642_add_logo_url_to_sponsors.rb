class AddLogoUrlToSponsors < ActiveRecord::Migration[8.0]
  def change
    add_column :sponsors, :logo_url, :string
  end
end
