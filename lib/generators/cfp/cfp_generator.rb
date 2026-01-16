require "rails/generators"

class CfpGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  class_option :event_series, type: :string, desc: "Event series folder name", required: true, group: "Fields"
  class_option :event, type: :string, desc: "Event folder name", required: true, aliases: ["-e"], group: "Fields"
  class_option :name, type: :string, desc: "CFP name", default: "Call for Proposals", group: "Fields"
  class_option :link, type: :string, desc: "CFP link", default: "", group: "Fields"
  class_option :open_date, type: :string, desc: "CFP open date (YYYY-MM-DD)", default: "2026-01-01", group: "Fields"
  class_option :close_date, type: :string, desc: "CFP close date (YYYY-MM-DD)", default: "2026-12-31", group: "Fields"

  def copy_cfp_file
    template "cfp.yml.tt", File.join(["data", options[:event_series], options[:event], "cfp.yml"])
  end
end
