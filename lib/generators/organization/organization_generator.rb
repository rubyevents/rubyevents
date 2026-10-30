# frozen_string_literal: true

require "rails/generators"

# Adds or updates an organization in data/organizations.yml, the file sponsors.yml and involvements.yml reference by slug.
class OrganizationGenerator < Rails::Generators::Base
  TOOL_DESC = "Add or update an organization in data/organizations.yml. Only the given fields change. Sponsors and involvements reference the organization by its slug."

  class_option :slug, type: :string, desc: "URL-friendly slug (defaults to the parameterized name)", required: false, group: "Fields"
  class_option :name, type: :string, desc: "Organization name, required when adding", required: false, group: "Fields"
  class_option :website, type: :string, desc: "Website URL", required: false, group: "Fields"
  class_option :logo_url, type: :string, desc: "URL of the logo to show", required: false, group: "Fields"
  class_option :description, type: :string, desc: "Description of the organization", required: false, group: "Fields"
  class_option :kind, type: :string, enum: OrganizationSchema::KINDS, desc: "Kind of organization", required: false, group: "Fields"
  class_option :main_location, type: :string, desc: "Where the organization is based (City, Country)", required: false, group: "Fields"
  class_option :alternate_names, type: :array, desc: "Other spellings or former names to add", required: false, group: "Fields"
  class_option :alias_slug, type: :string, desc: "A former slug to add as alias, together with --alias-name; sponsors and involvements using it are rewritten by bin/rails organizations_file:extract", required: false, group: "Fields"
  class_option :alias_name, type: :string, desc: "The name the organization was known under with --alias-slug (defaults to the current name)", required: false, group: "Fields"

  ATTRIBUTES = %i[name website logo_url description kind main_location].freeze

  def add_or_update_organization
    raise Thor::Error, "Pass --slug or --name" if options[:slug].blank? && options[:name].blank?

    organizations = Static::Organization.all
    organization = organizations.find_by(slug: slug)
    attributes = options.slice(*ATTRIBUTES.map(&:to_s)).compact_blank

    if organization
      organization.assign(**attributes.symbolize_keys)
      say "Updating organization #{organization.slug} in data/organizations.yml", :yellow
    else
      raise Thor::Error, "No organization with slug '#{slug}'. Pass --name to add it." if options[:name].blank?

      organization = Static::Organization.add(slug: slug, **attributes.symbolize_keys)
      say "Adding organization #{slug} to data/organizations.yml", :green
    end

    Array(options[:alternate_names]).each { |name| organization.add_alternate_name(name) }

    if options[:alias_slug].present?
      owner = organizations.find_by(slug: options[:alias_slug])
      raise Thor::Error, "Slug '#{options[:alias_slug]}' belongs to organization '#{owner.slug}'" if owner && owner != organization

      organization.add_alias(name: options[:alias_name].presence || organization.name, slug: options[:alias_slug])
    end

    organizations.save!
    say "Saved #{organization.slug}", :green
  end

  private

  def slug
    @slug ||= options[:slug].presence || Static::Organization.slug_for(options[:name])
  end
end
