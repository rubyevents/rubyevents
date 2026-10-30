# frozen_string_literal: true

class OrganizationUpdateTool < RubyLLM::Tool
  include OrganizationsFileCheck

  description "Update an organization's fields in data/organizations.yml. Use organization_lookup first to find the slug. Only provided fields are updated. When changing the slug, an alias for the old slug is created; run bin/rails organizations_file:extract afterwards to rewrite the sponsors and involvements that use the old slug."

  parameter :slug, description: "Slug of the organization to update (must match exactly)"
  parameter :new_slug, description: "New slug (the old slug becomes an alias)", required: false
  parameter :name, description: "New name (the old name is kept as an alternate name)", required: false
  parameter :website, description: "Website URL", required: false
  parameter :logo_url, description: "URL of the logo to show", required: false
  parameter :description, description: "Description of the organization", required: false
  parameter :kind, description: "One of #{OrganizationSchema::KINDS.join(", ")}", required: false
  parameter :main_location, description: "Where the organization is based (City, Country)", required: false
  parameter :logo_background, description: "One of #{OrganizationSchema::LOGO_BACKGROUNDS.join(", ")}", required: false

  UPDATABLE_FIELDS = %w[name website logo_url description kind main_location logo_background].freeze

  def execute(slug:, new_slug: nil, **fields)
    organization = organizations.find_by(slug: slug)
    return {error: "Organization '#{slug}' not found in organizations.yml"} unless organization

    updates = fields.select { |key, value| UPDATABLE_FIELDS.include?(key.to_s) && !value.nil? }
    return {error: "No fields to update. Provide at least one of: new_slug, #{UPDATABLE_FIELDS.join(", ")}"} if updates.empty? && new_slug.blank?
    return {error: "kind must be one of #{OrganizationSchema::KINDS.join(", ")}"} if updates[:kind].present? && OrganizationSchema::KINDS.exclude?(updates[:kind])
    return {error: "logo_background must be one of #{OrganizationSchema::LOGO_BACKGROUNDS.join(", ")}"} if updates[:logo_background].present? && OrganizationSchema::LOGO_BACKGROUNDS.exclude?(updates[:logo_background])

    alias_created = nil
    old_slug = organization["slug"]

    if new_slug.present? && new_slug != old_slug
      return {error: "Slug '#{new_slug}' is already taken in organizations.yml"} if organizations.known_slug?(new_slug)

      organization.add_alias(name: organization["name"], slug: old_slug)
      organization["slug"] = new_slug.to_s
      alias_created = old_slug
    end

    old_name = organization["name"]
    updates.each { |key, value| organization[key] = value.to_s }
    organization.add_alternate_name(old_name) if updates[:name].present? && updates[:name] != old_name

    organizations.save!

    result = {
      success: true,
      organization: organization["slug"],
      updated_fields: updates.transform_values(&:to_s),
      file: organizations.relative_path
    }
    result[:alias_created] = alias_created if alias_created
    result[:next_step] = "Run bin/rails organizations_file:extract to rewrite sponsors.yml and involvements.yml that use '#{old_slug}'" if alias_created

    check_organizations_file(result)
  rescue => e
    {error: e.message}
  end
end
