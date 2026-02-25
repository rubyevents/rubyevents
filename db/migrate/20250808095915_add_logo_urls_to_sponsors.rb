class AddLogoUrlsToSponsors < ActiveRecord::Migration[8.0]
  def change
    add_column :sponsors, :logo_urls, :json, default: []
    add_column :sponsors, :domain, :string
    add_column :sponsors, :logo_background, :string, default: "white"
  end
end
