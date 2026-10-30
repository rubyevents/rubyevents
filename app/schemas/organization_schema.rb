# frozen_string_literal: true

class OrganizationSchema < ApplicationSchema
  data_file "**/organizations.yml", selector: "[]"

  KINDS = %w[unknown company community foundation non_profit organisation].freeze
  LOGO_BACKGROUNDS = %w[white black transparent].freeze

  string :slug, description: "URL-friendly slug, the key that sponsors.yml and involvements.yml reference", required: true

  array :aliases, description: "Former slugs and the names they were known under; they redirect to this organization", required: false do
    object do
      string :name, required: true
      string :slug, required: true
    end
  end

  string :name, description: "Name of the organization", required: true

  array :alternate_names, description: "Other spellings and former names, kept for search and history", required: false do
    string
  end

  string :kind, description: "What kind of organization this is", required: false, enum: KINDS
  string :website, description: "Website URL", required: false

  array :websites, description: "Other website URLs seen for this organization (careers pages, regional sites)", required: false do
    string
  end

  string :logo_url, description: "URL of the logo to show", required: false

  array :logo_urls, description: "Other logo URLs seen for this organization", required: false do
    string
  end

  string :logo_background, description: "Background the logo is shown on", required: false, enum: LOGO_BACKGROUNDS
  string :main_location, description: "Where the organization is based (City, Country)", required: false
  string :description, description: "Description of the organization", required: false
end
