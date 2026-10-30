# frozen_string_literal: true

module OrganizationsFileCheck
  extend ActiveSupport::Concern

  def initialize(organizations_file_path: nil)
    @organizations_file_path = organizations_file_path

    super()
  end

  private

  def organizations
    @organizations ||= Static::Organization.in_file(@organizations_file_path || Static::Organization.file_path)
  end

  def check_organizations_file(result)
    missing = organizations.missing_organizations
    orphaned = organizations.orphaned_organizations

    warnings = []
    warnings << "#{missing.length} missing organization(s): #{missing.first(5).join(", ")}" if missing.any?
    warnings << "#{orphaned.length} orphaned organization(s): #{orphaned.first(5).join(", ")}" if orphaned.any?

    result[:warnings] = warnings if warnings.any?
    result
  end

  def organization_to_hash(organization)
    entry = organization.to_h

    result = {
      index: organization.index,
      slug: entry["slug"],
      name: entry["name"],
      kind: entry["kind"].presence,
      website: entry["website"].presence,
      logo_url: entry["logo_url"].presence,
      main_location: entry["main_location"].presence,
      description: entry["description"].presence
    }.compact

    aliases = Array(entry["aliases"]).filter_map { |entry_alias| entry_alias["slug"] if entry_alias.is_a?(Hash) }
    result[:aliases] = aliases if aliases.any?
    result[:alternate_names] = Array(entry["alternate_names"]) if Array(entry["alternate_names"]).any?
    result[:websites] = Array(entry["websites"]) if Array(entry["websites"]).any?

    result
  end
end
