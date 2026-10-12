# -*- SkipSchemaAnnotations
class Event::SponsorsFile < Event::DataFile
  data_file :sponsors, file_name: "sponsors.yml"

  def tiers
    entries.flat_map { |entry| entry["tiers"] || [] }
  end

  def tier_names
    tiers.map { |tier| tier["name"] }
  end

  def sponsors
    tiers.flat_map { |tier| tier["sponsors"] || [] }
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
