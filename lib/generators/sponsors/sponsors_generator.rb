# frozen_string_literal: true

require "generators/event_base"

class SponsorsGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)

  class_option :event_series, type: :string, desc: "Event series folder name", required: true, group: "Fields"
  class_option :event, type: :string, desc: "Event folder name", required: true, aliases: ["-e"], group: "Fields"
  argument :sponsors, type: :array, default: ["Sponsor Name:Sponsors"], banner: "sponsor_name[:tier][:badge] sponsor_name[:tier]"

  def initialize(args, *options)
    super
    sponsors_data = sponsors.map do |sponsor_arg|
      parts = sponsor_arg.split(":")
      {
        name: parts[0],
        tier: parts[1] || "Sponsors",
        slug: parts[0].downcase.tr(" ", "-"),
        badge: parts[2]
      }
    end
    @sponsors_by_tier = sponsors_data.group_by { |s| s[:tier] }
  end

  def copy_sponsors_file
    template "sponsors.yml.tt", File.join(["data", options[:event_series], options[:event], "sponsors.yml"])
  end
end
