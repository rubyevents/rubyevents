# frozen_string_literal: true

require "rails/generators"

# Generator for creating a series.yml for a new event series or meetup group, optionally nested in another series.
class SeriesGenerator < Rails::Generators::Base
  TOOL_DESC = "Create a series.yml file for a new event series or meetup group, optionally inside another series."

  class_option :series, type: :string, desc: "Series folder name (e.g. 'lrug')", required: true, group: "Fields"
  class_option :name, type: :string, desc: "Series name (e.g. 'London Ruby User Group')", required: true, group: "Fields"
  class_option :kind, type: :string, enum: SeriesSchema.properties[:kind][:enum], desc: "Series kind", default: "conference", group: "Fields"
  class_option :parent, type: :string, desc: "Folder name of the series to nest this one in (e.g. 'rails-girls')", group: "Fields"
  class_option :description, type: :string, desc: "Series description", group: "Fields"
  class_option :website, type: :string, desc: "Website URL", group: "Fields"
  class_option :language, type: :string, desc: "Primary language (e.g. 'English')", group: "Fields"
  class_option :default_country_code, type: :string, desc: "Default ISO country code (e.g. 'GB')", group: "Fields"
  class_option :location, type: :string, desc: "Where a meetup group meets (City, Country)", group: "Fields"
  class_option :timezone, type: :string, desc: "IANA timezone of a meetup group (e.g. Europe/London)", group: "Fields"
  class_option :meetup, type: :string, desc: "Meetup.com group URL", group: "Fields"
  class_option :luma, type: :string, desc: "Luma calendar URL", group: "Fields"
  class_option :kommunity, type: :string, desc: "Kommunity group URL", group: "Fields"

  ATTRIBUTES = (%i[kind description language default_country_code location timezone] + MeetupLinks::FIELDS.map(&:to_sym)).freeze

  def create_series
    parent = options[:parent].presence && Static::EventSeries.find_by_slug(options[:parent])
    raise Thor::Error, "Series '#{options[:parent]}' not found" if options[:parent].present? && parent.nil?
    raise Thor::Error, "Series '#{options[:series]}' already exists" if Static::EventSeries.find_by_slug(options[:series])

    series = Static::EventSeries.create(
      name: options[:name],
      slug: options[:series],
      parent: parent,
      **options.slice(*ATTRIBUTES.map(&:to_s)).symbolize_keys
    )

    Yerba.parse_file(series.file_path.to_s).save!(apply: true)

    say "Created #{series.project_file_path}", :green
  end
end
