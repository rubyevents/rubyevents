# frozen_string_literal: true

class OrganizationAddAliasTool < RubyLLM::Tool
  include OrganizationsFileCheck

  description "Add an alias (a former slug and the name it was known under) to an organization in data/organizations.yml, e.g. to merge a duplicate into it. Use organization_lookup first. Run bin/rails organizations_file:extract afterwards to rewrite the sponsors and involvements that use the alias slug."

  parameter :slug, description: "Slug of the organization to keep (must match exactly)"
  parameter :alias_slug, description: "The slug to redirect to this organization"
  parameter :alias_name, description: "The name the organization was known under with that slug (defaults to the organization's name)", required: false

  def execute(slug:, alias_slug:, alias_name: nil)
    organization = organizations.find_by(slug: slug)
    return {error: "Organization '#{slug}' not found in organizations.yml"} unless organization

    alias_slug = alias_slug.to_s
    return {error: "Alias slug '#{alias_slug}' already exists for #{slug}"} if organization.alias_slugs.include?(alias_slug)

    owner = organizations.find_by(slug: alias_slug)
    if owner && owner != organization
      return {error: "Slug '#{alias_slug}' belongs to organization '#{owner["slug"]}'. Remove that entry (its data moves into the aliases of #{slug}) before adding the alias."}
    end

    name = alias_name.presence || organization["name"]
    organization.add_alias(name: name, slug: alias_slug)

    organizations.save!

    check_organizations_file({
      success: true,
      organization: slug,
      alias_added: {name: name, slug: alias_slug},
      total_aliases: organization.alias_slugs.size,
      file: organizations.relative_path,
      next_step: "Run bin/rails organizations_file:extract to rewrite sponsors.yml and involvements.yml that use '#{alias_slug}'"
    })
  rescue => e
    {error: e.message}
  end
end
