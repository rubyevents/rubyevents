# -*- SkipSchemaAnnotations
class Event::SponsorsFile < ActiveRecord::AssociatedObject
  FILE_NAME = "sponsors.yml"

  def file_path
    event.data_folder.join(FILE_NAME)
  end

  def exist?
    file_path.exist?
  end

  def file
    YAML.load_file(file_path)
  end

  def tier_names
    # Returns an array of all tier names from the sponsors.yml file
    data = file
    tiers = data[:tiers] || data["tiers"] || []
    tiers.map { |tier| tier[:name] || tier["name"] }
  end

  def sponsors
    # Returns a flat array of all sponsors from all tiers, regardless of level
    data = file
    tiers = data[:tiers] || data["tiers"] || []
    tiers.flat_map { |tier| tier[:sponsors] || tier["sponsors"] || [] }
  end

  def download
    DownloadSponsors.new.download_sponsors(event.website, save_file: event.data_folder.join(FILE_NAME) )
  end

end
