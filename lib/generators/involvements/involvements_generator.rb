# frozen_string_literal: true

require "generators/event_base"

# Generator for creating a new involvement entry in the involvements.yml file of a specific event.
class InvolvementsGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)

  class_option :name, type: :string, desc: "Role or involvement type (e.g., 'Organizer', 'Program Committee member')", required: true, group: "Fields"
  class_option :users, type: :array, desc: "Person names involved in this role", required: false, group: "Fields"
  class_option :organisations, type: :array, desc: "Organization names involved in this role", required: false, group: "Fields"

  def involvements_file_path
    @involvements_file_path ||= File.join(event_directory, "involvements.yml")
  end

  def involvement_attributes
    @involvement ||= {
      "name" => options[:name].singularize,
      "users" => options[:users],
      "organisations" => options[:organisations]
    }.compact
  end

  def ensure_file_exists
    template "header.yml.tt", involvements_file_path unless File.exist?(involvements_file_path)
  end

  def upsert_involvement_entry
    yaml_upsert involvements_file_path, involvement_attributes, unique_by: {name: involvement_attributes["name"]}
  end
end
