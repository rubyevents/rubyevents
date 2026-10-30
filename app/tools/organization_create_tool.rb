# frozen_string_literal: true

class OrganizationCreateTool < RubyLLM::Tool
  include OrganizationsFileCheck

  description "Add a new organization to data/organizations.yml. Use organization_lookup first to verify it doesn't already exist, also under another spelling."

  parameter :name, description: "Name of the organization"
  parameter :slug, description: "URL-friendly slug (auto-generated from name if not provided)", required: false
  parameter :website, description: "Website URL", required: false
  parameter :logo_url, description: "URL of the logo to show", required: false
  parameter :description, description: "Description of the organization", required: false
  parameter :kind, description: "One of #{OrganizationSchema::KINDS.join(", ")}", required: false
  parameter :main_location, description: "Where the organization is based (City, Country)", required: false

  def execute(name:, slug: nil, **fields)
    slug = (slug.presence || Static::Organization.slug_for(name)).to_s

    return {error: "Organization '#{name}' already exists in organizations.yml"} if organizations.find_by(name: name)
    return {error: "An organization with slug '#{slug}' already exists in organizations.yml"} if organizations.known_slug?(slug)
    return {error: "kind must be one of #{OrganizationSchema::KINDS.join(", ")}"} if fields[:kind].present? && OrganizationSchema::KINDS.exclude?(fields[:kind])

    organizations.add(slug: slug, name: name, **fields.compact)
    organizations.save!

    check_organizations_file({
      success: true,
      organization: name,
      slug: slug,
      file: organizations.relative_path
    })
  rescue => e
    {error: e.message}
  end
end
