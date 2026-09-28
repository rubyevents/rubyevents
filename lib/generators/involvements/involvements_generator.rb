# frozen_string_literal: true

require "generators/event_base"

# Generator for creating a new involvement entry in the involvements.yml file of a specific event.
class InvolvementsGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)
  TOOL_DESC = "Create or update a new involvement entry in the involvements.yml file of a given event."

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

  def yerba_document
    @document ||= Yerba.parse_file(involvements_file_path)
  end

  def delete_existing_involvement_entry
    yerba_document.root.each do |entry|
      if entry["name"].value == involvement_attributes["name"]
        entry.delete
        say "Existing involvement entry '#{involvement_attributes["name"]}' found, updating...", :yellow
      end
    end
  end

  def add_involvement_entry
    yerba_document << involvement_attributes
    yerba_document.save!(apply: true)
    say "Added involvement entry '#{involvement_attributes["name"]}' to #{involvements_file_path}", :green
  end
end
