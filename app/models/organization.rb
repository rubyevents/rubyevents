# == Schema Information
#
# Table name: organizations
# Database name: primary
#
#  id              :integer          not null, primary key
#  description     :text
#  domain          :string
#  kind            :integer          default("unknown"), not null, indexed
#  logo_background :string           default("white")
#  logo_url        :string
#  logo_urls       :json
#  main_location   :string
#  name            :string
#  slug            :string           indexed
#  website         :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_organizations_on_kind  (kind)
#  index_organizations_on_slug  (slug)
#
class Organization < ApplicationRecord
  include Sluggable
  include UrlNormalizable
  include Organization::TypesenseSearchable

  configure_slug(attribute: :name, auto_suffix_on_collision: false)

  # enums
  enum :kind, {unknown: 0, company: 1, community: 2, foundation: 3, non_profit: 4}

  # attachments
  has_one_attached :wrapped_card_horizontal

  # associations
  has_many :aliases, as: :aliasable, dependent: :destroy
  has_many :sponsors, dependent: :destroy
  has_many :events, through: :sponsors
  has_many :event_involvements, as: :involvementable, dependent: :destroy
  has_many :involved_events, through: :event_involvements, source: :event

  validates :name, presence: true, uniqueness: true

  before_save :ensure_unique_logo_urls

  def self.find_by_name_or_alias(name)
    return nil if name.blank?

    organization = find_by(name: name)
    return organization if organization

    alias_record = ::Alias.find_by(aliasable_type: "Organization", name: name)
    alias_record&.aliasable
  end

  def self.find_by_slug_or_alias(slug)
    return nil if slug.blank?

    organization = find_by(slug: slug)
    return organization if organization

    alias_record = ::Alias.find_by(aliasable_type: "Organization", slug: slug)
    alias_record&.aliasable
  end

  normalize_url :website

  def organization_image_path
    ["organizations", slug].join("/")
  end

  def default_organization_image_path
    ["organizations", "default"].join("/")
  end

  def organization_image_or_default_for(filename)
    org_path = [organization_image_path, filename].join("/")
    default_path = [default_organization_image_path, filename].join("/")

    base = Rails.root.join("app", "assets", "images")

    return org_path if (base / org_path).exist?

    default_path
  end

  def organization_image_for(filename)
    org_path = [organization_image_path, filename].join("/")

    Rails.root.join("app", "assets", "images", organization_image_path, filename).exist? ? org_path : nil
  end

  def avatar_image_path
    organization_image_or_default_for("avatar.webp")
  end

  def banner_image_path
    organization_image_or_default_for("banner.webp")
  end

  def logo_image_path
    # First try local asset, then fallback to logo_url
    if organization_image_for("logo.webp")
      organization_image_or_default_for("logo.webp")
    elsif logo_url.present?
      logo_url
    else
      organization_image_or_default_for("logo.webp")
    end
  end

  def has_logo_image?
    organization_image_for("logo.webp").present? || logo_url.present?
  end

  def logo_background_class
    case logo_background
    when "black"
      "bg-black"
    when "transparent"
      "bg-transparent"
    else
      "bg-white"
    end
  end

  def logo_border_class
    case logo_background
    when "black"
      "border-gray-600"
    when "transparent"
      "border-gray-300"
    else
      "border-gray-200"
    end
  end

  def add_logo_url(url)
    return if url.blank?

    self.logo_urls ||= []
    self.logo_urls << url unless logo_urls.include?(url)

    logo_urls.uniq!
  end

  private

  def ensure_unique_logo_urls
    self.logo_urls = (logo_urls || []).uniq.reject(&:blank?)
  end
end
