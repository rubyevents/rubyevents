# frozen_string_literal: true

require "generators/event_base"

class CfpGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)

  class_option :name, type: :string, desc: "CFP name", group: "Fields"
  class_option :link, type: :string, desc: "CFP link", group: "Fields"
  class_option :open_date, type: :string, desc: "CFP open date (YYYY-MM-DD)", group: "Fields"
  class_option :close_date, type: :string, desc: "CFP close date (YYYY-MM-DD)", group: "Fields"

  CFP = Struct.new("CFP", :name, :link, :open_date, :close_date)

  def cfp_file
    @cfp_file = File.join([event_directory, "cfp.yml"])
  end

  def ensure_cfp_file_exists
    template "header.yml.tt", @cfp_file unless File.exist?(@cfp_file)
  end

  def find_and_delete_existing_cfp
    @existing_cfp = nil
    if File.read(@cfp_file).match?(/(name: "#{options[:name]}"|link: "#{options[:link]}")/)
      document = Yerba.parse_file(@cfp_file)
      document["[]"].each do |cfp_entry|
        if cfp_entry["name"] == options[:name] || cfp_entry["link"] == options[:link]
          say "CFP with name '#{cfp_entry["name"]}' and link '#{cfp_entry["link"]}' already exists in #{@cfp_file}. Modifying existing CFP.", :yellow
          @existing_cfp = cfp_entry.to_h
          file_location = cfp_entry.location
          # Delete CFP entry here
        end
      end
    end
  end

  def create_cfp_record
    @cfp = CFP.new(
      name: options[:name] || @existing_cfp[:name] || "Call for Proposals",
      link: options[:link] || @existing_cfp[:link] || "https://www.TODO.example.com/cfp",
      open_date: options[:open_date] || @existing_cfp[:open_date] || Date.today.iso8601,
      close_date: options[:close_date] || @existing_cfp[:close_date] || static_event&.start_date
    )

    append_to_file @cfp_file, template_content("cfp.yml.tt")
  end
end
