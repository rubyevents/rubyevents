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
    # Default to event website as base_url if no arguments provided
    if [base_url, sponsors_url, html].compact.empty?
      base_url = event.website
    end

    # Log which input method is being used
    if html
      puts "Using HTML content: #{html.length} characters"
    elsif sponsors_url
      puts "Using sponsors URL: #{sponsors_url}"
    elsif base_url
      puts "Using base URL: #{base_url}"
    end

    DownloadSponsors.new.download_sponsors(
      base_url: base_url,
      sponsors_url: sponsors_url,
      html: html,
      save_file: event.data_folder.join(FILE_NAME)
    )
  end
end
