class Stamp
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :code, :string
  attribute :name, :string
  attribute :file_path, :string
  attribute :country
  attribute :has_country, :boolean, default: false

  def self.all
    @all_stamps ||= load_stamps_from_filesystem
  end

  def self.grouped_by_continent
    stamps_by_continent = all.select(&:has_country?).group_by { |stamp| stamp.country&.continent }
    custom_stamps = all.reject(&:has_country?)

    stamps_by_continent["Custom"] = custom_stamps if custom_stamps.any?

    stamps_by_continent
  end

  def self.missing_for_events
    event_countries = Event.all.map { |event| event.static_metadata&.country }.compact.uniq
    stamp_countries = all.select(&:has_country?).map(&:country).compact.uniq

    event_countries.reject { |event_country|
      stamp_countries.include?(event_country) || (event_country == ISO3166::Country.new("GB") && uk_subdivisions_covered?)
    }.sort_by { |c| c.translations["en"] }
  end

  def asset_path
    ActionController::Base.helpers.asset_path("stamps/#{File.basename(file_path)}")
  end

  def has_country?
    has_country
  end

  def self.load_stamps_from_filesystem
    stamps_directory = Rails.root.join("app", "assets", "images", "stamps")
    return [] unless File.directory?(stamps_directory)

    stamp_files = Dir.glob(File.join(stamps_directory, "*.webp")).map { |file| File.basename(file, ".webp") }

    stamp_files.map { |stamp_code| create_stamp_from_code(stamp_code) }.compact.sort_by(&:name)
  end

  def self.create_stamp_from_code(stamp_code)
    stamp_upper = stamp_code.upcase
    file_path = "#{stamp_code}.webp"

    case stamp_upper
    when "SCT", "SCOTLAND", "GB-SCT"
      new(
        code: "SCT",
        name: "Scotland",
        file_path: file_path,
        country: ISO3166::Country.new("GB"),
        has_country: true
      )
    when "ENG", "ENGLAND", "GB-ENG"
      new(
        code: "ENG",
        name: "England",
        file_path: file_path,
        country: ISO3166::Country.new("GB"),
        has_country: true
      )
    when "NIR", "NI", "NORTHERN-IRELAND", "GB-NIR"
      new(
        code: "NIR",
        name: "Northern Ireland",
        file_path: file_path,
        country: ISO3166::Country.new("GB"),
        has_country: true
      )
    when "WLS", "WALES", "GB-WLS"
      new(
        code: "WLS",
        name: "Wales",
        file_path: file_path,
        country: ISO3166::Country.new("GB"),
        has_country: true
      )
    else
      country = ISO3166::Country.new(stamp_upper)
      if country
        new(
          code: stamp_upper,
          name: country.translations["en"],
          file_path: file_path,
          country: country,
          has_country: true
        )
      else
        new(
          code: stamp_upper,
          name: stamp_code.titleize,
          file_path: file_path,
          country: nil,
          has_country: false
        )
      end
    end
  end

  def self.uk_subdivisions_covered?
    uk_subdivision_codes = ["SCT", "ENG", "NIR", "WLS"]

    all.any? { |stamp| uk_subdivision_codes.include?(stamp.code) }
  end
end
