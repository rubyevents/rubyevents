# frozen_string_literal: true

require "generators/event_base"

# Adds or updates sponsors in the sponsors.yml file of an event, or of a series with --series-level.
# Sponsors reference an organization in data/organizations.yml by slug; every organization has to be there already.
class SponsorsGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)
  TOOL_DESC = "Add or update sponsors in the sponsors.yml file of a given event, each given as slug_or_name|tier|badge " \
    "(with --series-level: slug_or_name|tier|badge|from|to). Sponsors reference data/organizations.yml by slug; " \
    "add an organization that isn't there yet with organization_create first."
  DEFAULT_TIER = "Sponsors"

  class_option :sponsors, type: :array, desc: "Sponsors as slug_or_name|tier|badge, with --series-level slug_or_name|tier|badge|from|to " \
    "(from and to as YYYY, YYYY-MM or YYYY-MM-DD). Everything after slug_or_name is optional; a sponsor already in the file " \
    "keeps its tier, a new one defaults to #{DEFAULT_TIER}", required: false, group: "Fields"

  series_level_files!

  class_option :tiers, type: :string, desc: "Comma-separated list of all sponsorship tiers, highest first (e.g. 'Platinum,Gold'). " \
    "A new file gets these, or else the tiers of --sponsors in the order they first appear", required: false, group: "Fields"

  def parse_sponsors
    @sponsors = Array(options[:sponsors]).map do |argument|
      slug_or_name, tier, badge, from, to = argument.split("|").map { |part| part.strip.presence }
      raise Thor::Error, "Sponsor '#{argument}' has no slug or name" if slug_or_name.nil?
      raise Thor::Error, "Sponsor '#{argument}' has from or to, which only a series' file takes (--series-level)" if (from || to) && !options[:series_level]

      {organization: slug_or_name, tier: tier, badge: badge, from: from, to: to}
    end
  end

  # Before anything is written, so one unknown organization stops the whole call
  def ensure_organizations_exist
    @sponsors.each { |sponsor| sponsor[:slug] = known_slug(sponsor[:organization]) }
    unknown = @sponsors.reject { |sponsor| sponsor[:slug] }.map { |sponsor| sponsor[:organization] }.uniq
    return if unknown.empty?

    raise Thor::Error, "Not in #{Static::Organization.file_path}: #{unknown.map { |value| "'#{value}'" }.join(", ")}. " \
      "Check the spelling, or add the organization with bin/rails g organization (MCP: organization_create) first."
  end

  def ensure_file_exists
    return if File.exist?(sponsors_file)

    @tiers = options[:tiers]&.split(",") || @sponsors.map { |sponsor| sponsor[:tier] || DEFAULT_TIER }.uniq(&:downcase).presence || [DEFAULT_TIER]
    say "Creating new sponsors file: #{sponsors_file}", :green
    template "header.yml.tt", sponsors_file
  end

  def add_sponsors
    @sponsors.each do |sponsor|
      tier_name = sponsor[:tier]
      existing_tier, existing = existing_entry(sponsor)

      if existing
        say "Existing sponsor found: #{sponsor[:slug]}. Updating...", :yellow
        tier_name ||= existing_tier["name"]
        sponsor[:badge] ||= existing["badge"]
        sponsor[:to] ||= existing["to"]
        existing.destroy
        @sponsor_tiers = nil
      end

      tier_name ||= DEFAULT_TIER
      tier = sponsor_tiers.find { |t| t["name"]&.downcase == tier_name.downcase } || sponsor_tiers.last
      say "Adding sponsor #{sponsor[:slug]} to tier: #{tier["name"]}", :green
      tier.sponsors.create(sponsor.slice(:slug, :badge, :from, :to).compact)
    end

    # Years like 2018 would read as numbers
    gsub_file sponsors_file, /^(\s+(?:from|to): )(\d{4}(?:-\d{2}(?:-\d{2})?)?)$/, '\1"\2"', verbose: false
  end

  private

  def sponsors_file
    @sponsors_file ||= File.join(target_directory, "sponsors.yml")
  end

  def sponsor_tiers
    @sponsor_tiers ||= Static::Sponsor.in_file(sponsors_file).first.tiers
  end

  # The current slug of the organization with exactly this slug, alias slug, name, alias name or alternate name
  def known_slug(slug_or_name)
    organization = Static::Organization.find_by(slug: slug_or_name) || Static::Organization.named(slug_or_name)

    organization&.slug
  end

  # The entry already in the file for this sponsor, and its tier. A series' file lists an organization once per period.
  def existing_entry(sponsor)
    sponsor_tiers.each do |tier|
      entry = tier.sponsors.to_a.find do |candidate|
        Static::Organization.find_by(slug: candidate["slug"].to_s)&.slug == sponsor[:slug] &&
          (!options[:series_level] || ::Sponsor.period_start(candidate["from"]) == ::Sponsor.period_start(sponsor[:from]))
      end

      return [tier, entry] if entry
    end

    nil
  end
end
