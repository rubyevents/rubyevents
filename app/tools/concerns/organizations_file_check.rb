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
end
