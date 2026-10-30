# frozen_string_literal: true

require "generators/event_base"

# Add or update a sponsor entry in the sponsors.yml file for a given event.
# Sponsors reference an organization in data/organizations.yml by slug; an unknown slug is added there
# when --name is given.
class SponsorsGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)
  TOOL_DESC = "Add or update a sponsor in the sponsors.yml file of a given event. Sponsors reference data/organizations.yml by slug; pass --name (and --website, --logo_url) to add an organization that isn't there yet."

  class_option :slug, type: :string, desc: "Slug of the organization in data/organizations.yml (defaults to the parameterized --name)", required: false, group: "Fields"
  class_option :name, type: :string, desc: "Organization name, used to find or add the organization", required: false, group: "Fields"
  class_option :website, type: :string, desc: "Organization website, written to data/organizations.yml when the organization is added", required: false, group: "Fields"
  class_option :logo_url, type: :string, desc: "URL to the organization's logo, written to data/organizations.yml when the organization is added", required: false, group: "Fields"
  class_option :tier, type: :string, desc: "Sponsor tier (e.g. Platinum, Gold)", default: "Sponsors", group: "Fields"
  class_option :badge, type: :string, desc: "Sponsor badge", required: false, group: "Fields"
  class_option :from, type: :string, desc: "With --series-level: when the sponsorship started (YYYY, YYYY-MM or YYYY-MM-DD)", required: false, group: "Fields"
  class_option :to, type: :string, desc: "With --series-level: when the sponsorship ended (YYYY, YYYY-MM or YYYY-MM-DD)", required: false, group: "Fields"

  series_level_files!

  class_option :tiers, type: :string, desc: "Comma-separated list of all sponsorship tiers (e.g. 'Platinum,Gold'), include on first run", required: false, group: "Fields"

  def sponsors_file
    @sponsors_file ||= File.join(target_directory, "sponsors.yml")
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

  def ensure_organization_exists
    return unless sponsor_details_provided?

    organization = Static::Organization.find_by(slug: slug)

    if organization
      @slug = organization.slug
      return
    end

    if options[:name].blank?
      raise Thor::Error, "No organization with slug '#{slug}' in #{Static::Organization.file_path}. Pass --name (and --website, --logo_url) to add it, or run bin/rails g organization."
    end

    Static::Organization.add(slug: slug, name: options[:name], website: options[:website], logo_url: options[:logo_url])
    Static::Organization.save!
    say "Added organization '#{options[:name]}' (#{slug}) to data/organizations.yml", :green
  end

  def sponsor_tiers
    @sponsor_tiers ||= Static::Sponsor.in_file(sponsors_file).first.tiers
  end

  def find_and_delete_existing_sponsor_in_file
    return unless sponsor_details_provided?

    file_sponsor = sponsor_tiers.flat_map { |tier| tier.sponsors.to_a }.find { |sponsor| sponsor["slug"] == slug }
    return unless file_sponsor

    say "Existing sponsor found: #{file_sponsor["slug"]}. Updating...", :yellow
    @badge = options[:badge].presence || file_sponsor["badge"]
    @from = options[:from].presence || file_sponsor["from"]
    @to = options[:to].presence || file_sponsor["to"]
    file_sponsor.destroy
    @sponsor_tiers = nil
  end

  def add_sponsor_to_tier
    if sponsor_details_provided?
      tier = sponsor_tiers.find { |t| t["name"]&.downcase == options[:tier].to_s.downcase } || sponsor_tiers.last
      say "Adding sponsor #{slug} to tier: #{tier["name"]}", :green
      tier.sponsors.create({slug: slug, badge: @badge || options[:badge], from: @from || options[:from], to: @to || options[:to]}.compact)
      gsub_file sponsors_file, /^(\s+(?:from|to): )(\d{4}(?:-\d{2}(?:-\d{2})?)?)$/, '\1"\2"', verbose: false
    else
      say "No sponsor details provided, skipping sponsor addition", :yellow
    end
  end

  private

  def slug
    @slug ||= options[:slug].presence || Static::Organization.slug_for(options[:name])
  end

  def sponsor_details_provided?
    options[:slug].present? || options[:name].present?
  end
end
