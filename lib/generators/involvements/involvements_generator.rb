# frozen_string_literal: true

require "generators/event_base"

# Generator for creating a new involvement entry in the involvements.yml file of a specific event.
class InvolvementsGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)
  TOOL_DESC = "Create or update a new involvement entry in the involvements.yml file of a given event. Organizations are referenced by their slug in data/organizations.yml."

  class_option :name, type: :string, desc: "Role or involvement type (e.g., 'Organizer', 'Program Committee member')", required: true, group: "Fields"
  class_option :users, type: :array, desc: "Person names involved in this role", required: false, group: "Fields"
  class_option :organizations, type: :array, desc: "Slugs of organizations (data/organizations.yml) involved in this role", required: false, group: "Fields"
  class_option :from, type: :string, desc: "With --series-level: when the users and organizations started in this role (YYYY, YYYY-MM or YYYY-MM-DD)", required: false, group: "Fields"
  class_option :to, type: :string, desc: "With --series-level: when they ended in this role (YYYY, YYYY-MM or YYYY-MM-DD)", required: false, group: "Fields"

  series_level_files!

  def involvements_file_path
    @involvements_file_path ||= File.join(target_directory, "involvements.yml")
  end

  def ensure_organizations_exist
    unknown = Array(options[:organizations]).reject { |slug| Static::Organization.find_by(slug: slug) }
    return if unknown.empty?

    raise Thor::Error, "No organization with slug #{unknown.map { |slug| "'#{slug}'" }.join(", ")} in #{Static::Organization.file_path}. Add it with bin/rails g organization first."
  end

  def involvement_attributes
    @involvement ||= {
      "name" => options[:name].singularize,
      "users" => with_period(options[:users], "name"),
      "organizations" => with_period(options[:organizations]&.map { |slug| Static::Organization.find_by(slug: slug).slug }, "slug")
    }.compact
  end

  def ensure_file_exists
    template "header.yml.tt", involvements_file_path unless File.exist?(involvements_file_path)
  end

  def involvements
    @involvements ||= Static::Involvement.in_file(involvements_file_path)
  end

  def delete_existing_involvement_entry
    existing = involvements.where(name: involvement_attributes["name"]).to_a

    existing.each { say "Existing involvement entry '#{involvement_attributes["name"]}' found, updating...", :yellow }
    existing.reverse_each { |involvement| involvements.destroy(involvement) }
  end

  def add_involvement_entry
    involvements.create(involvement_attributes)
    quote_periods(involvements_file_path)
    say "Added involvement entry '#{involvement_attributes["name"]}' to #{involvements_file_path}", :green
  end

  private

  # Years like 2018 would read as numbers
  def quote_periods(path)
    gsub_file path, /^(\s+(?:from|to): )(\d{4}(?:-\d{2}(?:-\d{2})?)?)$/, '\1"\2"', verbose: false
  end

  def with_period(values, key)
    return values if values.nil? || (options[:from].blank? && options[:to].blank?)

    values.map { |value| {key => value, "from" => options[:from], "to" => options[:to]}.compact }
  end
end
