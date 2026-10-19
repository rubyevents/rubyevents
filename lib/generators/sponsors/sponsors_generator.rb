# frozen_string_literal: true

require "generators/event_base"

# Add or update a Sponsor entry in the sponsors.yml file for a given event.
class SponsorsGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)
  TOOL_DESC = "Add or update a Sponsor entry in the sponsors.yml file for a given event."

  class_option :name, type: :string, desc: "Sponsor name", required: false, group: "Fields"
  class_option :website, type: :string, desc: "Sponsor website", required: false, group: "Fields"
  class_option :tier, type: :string, desc: "Sponsor tier (e.g. Platinum, Gold)", default: "Sponsors", group: "Fields"
  class_option :logo_url, type: :string, desc: "URL to sponsor logo", required: false, group: "Fields"
  class_option :badge, type: :string, desc: "Sponsor badge", required: false, group: "Fields"
  class_option :tiers, type: :string, desc: "Comma-separated list of all sponsorship tiers (e.g. 'Platinum,Gold'), include on first run", required: false, group: "Fields"

  Sponsor = Struct.new("Sponsor", :name, :website, :slug, :logo_url, :tier, :badge) do |sponsor_struct|
    def for_document
      {
        name: name,
        website: website,
        slug: slug,
        logo_url: logo_url,
        badge: badge
      }.compact
    end
  end

  def sponsors_file
    @sponsors_file ||= File.join(event_directory, "sponsors.yml")
  end

  def tiers
    @tiers ||= options[:tiers]&.split(",") || ["Sponsors"]
  end

  def ensure_file_exists
    unless File.exist?(sponsors_file)
      say "Creating new sponsors file: #{sponsors_file}", :green
      template "header.yml.tt", sponsors_file
    end
  end

  def sponsor_details
    # Later :)
    # @existing_sponsor ||= Static::Sponsor.find_sponsor_by_any(name: options[:name], url: options[:website], slug:)

    @sponsor_details ||= Sponsor.new(
      name: options[:name],
      website: options[:website],
      slug: options[:name]&.parameterize,
      logo_url: options[:logo_url],
      tier: options[:tier],
      badge: options[:badge]
    )
  end

  def sponsor_tiers
    @sponsor_tiers ||= Static::Sponsor.in_file(sponsors_file).first.tiers
  end

  def find_and_delete_existing_sponsor_in_file
    return unless sponsor_details_provided?
    file_sponsor = sponsor_tiers.flat_map { |tier| tier.sponsors.to_a }.find do |sponsor|
      sponsor["name"]&.downcase == sponsor_details.name&.downcase
        || sponsor["website"] == sponsor_details.website
        || sponsor["slug"] == sponsor_details.slug
    end
    if file_sponsor
      say "Existing sponsor found: #{file_sponsor["name"]}. Updating...", :yellow
      sponsor_details.name ||= file_sponsor["name"]
      sponsor_details.website ||= file_sponsor["website"]
      sponsor_details.slug ||= file_sponsor["slug"]
      sponsor_details.logo_url ||= file_sponsor["logo_url"]
      sponsor_details.badge ||= file_sponsor["badge"]
      file_sponsor.destroy
      @sponsor_tiers = nil
    end
  end

  def add_sponsor_to_tier
    if sponsor_details_provided?
      tier = sponsor_tiers.find { |t| t["name"]&.downcase == options[:tier].to_s.downcase }
        || sponsor_tiers.last
      say "Adding sponsor to tier: #{tier["name"]}", :green
      tier.sponsors.create(sponsor_details.for_document)
    else
      say "No sponsor details provided, skipping sponsor addition", :yellow
    end
  end

  private

  def sponsor_details_provided?
    options[:name] || options[:website]
  end
end
