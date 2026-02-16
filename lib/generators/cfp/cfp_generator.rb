# frozen_string_literal: true

require "generators/event_base"

class CfpGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)

  class_option :name, type: :string, desc: "CFP name", default: "Call for Proposals", group: "Fields"
  class_option :link, type: :string, desc: "CFP link", default: "https://TODO.example.com/cfp", group: "Fields"
  class_option :open_date, type: :string, desc: "CFP open date (YYYY-MM-DD)", default: "2026-01-01", group: "Fields"
  class_option :close_date, type: :string, desc: "CFP close date (YYYY-MM-DD)", default: "2026-12-31", group: "Fields"

  def copy_cfp_file
    cfp_file = File.join(["data", options[:event_series], options[:event], "cfp.yml"])
    template "header.yml.tt", cfp_file unless File.exist?(destination_path(cfp_file))

    if File.read(destination_path(cfp_file)).include?(options[:name])
      gsub_file cfp_file, /- name: "#{options[:name]}"\s*(link: "[^"]*"\s*)(open_date: "[^"]*"\s*)?(close_date: "[^"]*"\s*)?/, template_content("cfp.yml.tt")
    else
      append_to_file cfp_file, template_content("cfp.yml.tt")
    end
  end
end
