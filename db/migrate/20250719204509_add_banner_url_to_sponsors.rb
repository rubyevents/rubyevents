class AddBannerUrlToSponsors < ActiveRecord::Migration[8.0]
  def change
    add_column :sponsors, :banner_url, :string
  end
end
