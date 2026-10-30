# frozen_string_literal: true

class OrganizationLookupTool < RubyLLM::Tool
  include OrganizationsFileCheck

  description "Search for organizations (sponsors, organizing companies and communities) in data/organizations.yml by slug, name, alias, alternate name or website. Returns matching organizations with their info."
  parameter :query, description: "Search query (matches against slug, name, aliases, alternate names, websites). Case-insensitive."

  def execute(query:)
    q = query.downcase

    matches = organizations.filter_map do |organization|
      searchable = [organization["slug"], *organization.all_names, *organization.alias_slugs, *organization.all_websites]
      next unless searchable.compact.any? { |value| value.to_s.downcase.include?(q) }

      organization_to_hash(organization)
    end

    matches.first(25)
  rescue => e
    {error: e.message}
  end
end
