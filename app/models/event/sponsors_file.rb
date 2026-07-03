# -*- SkipSchemaAnnotations
class Event::SponsorsFile < ActiveRecord::AssociatedObject
  include YAMLFile

  yaml_file "sponsors.yml"

  def tier_names
    tiers = file[:tiers] || file["tiers"] || []

    tiers.map { |tier| tier[:name] || tier["name"] }
  end

  def sponsors
    tiers = file[:tiers] || file["tiers"] || []

    tiers.flat_map { |tier| tier[:sponsors] || tier["sponsors"] || [] }
  end

  # Option 1: Use event website as base URL
  #   event.sponsors_file.download
  #
  # Option 2: Specify a different base URL
  #   event.sponsors_file.download(base_url: "https://example.com/conference")
  #
  # Option 3: Direct sponsors URL
  #   event.sponsors_file.download(sponsors_url: "https://example.com/sponsors")
  #
  # Option 4: Raw HTML content
  #   event.sponsors_file.download(html: "<html>...</html>")
  #
  def download(base_url: nil, sponsors_url: nil, html: nil)
    raise NotImplementedError, "Download method is being removed because the supporting download script no longer succeeds."
  end
end
