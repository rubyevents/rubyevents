# frozen_string_literal: true

# Sponsors and involvements reference data/organizations.yml, and generators and tools add to it.
# Include this in tests that do so, to point Static::Organization at an empty throwaway file, and add
# the organizations a test needs with `sandbox_organizations`.
module StaticOrganizationsSandbox
  extend ActiveSupport::Concern

  included do
    setup do
      @sandboxed_organizations_file = Tempfile.new(["organizations", ".yml"])
      File.write(@sandboxed_organizations_file.path, "---\n[]\n")

      @original_organizations_path = Static::Organization.path
      Static::Organization.path = @sandboxed_organizations_file.path
      Static::Organization.unload!
    end

    teardown do
      Static::Organization.path = @original_organizations_path
      Static::Organization.unload!

      @sandboxed_organizations_file.close
      @sandboxed_organizations_file.unlink
    end
  end

  # Adds organizations to the sandboxed file, so tests can reference them by slug
  def sandbox_organizations(*entries)
    organizations = Static::Organization.all
    entries.each { |entry| organizations.build(entry.transform_keys(&:to_s)) }
    organizations.save!
    Static::Organization.unload!
  end
end
