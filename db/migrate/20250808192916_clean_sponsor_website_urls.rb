class CleanSponsorWebsiteUrls < ActiveRecord::Migration[8.0]
  def change
    say_with_time "Normalizing existing sponsor website URLs" do
      Sponsor.find_each do |sponsor|
        if sponsor.website.present?
          normalized = UrlNormalizable.normalize_url_string(sponsor.website)
          if normalized != sponsor.website
            sponsor.update_column(:website, normalized)
          end
        end
      end
    end
  end
end
