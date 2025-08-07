# == Schema Information
#
# Table name: sponsors
#
#  id            :integer          not null, primary key
#  description   :text
#  logo_url      :string
#  main_location :string
#  name          :string
#  slug          :string           indexed
#  website       :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_sponsors_on_slug  (slug)
#
class Sponsor < ApplicationRecord
  include Sluggable
  slug_from :name

  # associations
  has_many :event_sponsors, dependent: :destroy
  has_many :events, through: :event_sponsors

  validates :name, presence: true, uniqueness: true

  normalizes :website, with: ->(website) {
    return "" if website.blank?

    # if it already starts with https://, return as is
    return website if website.start_with?("https://")

    # if it starts with http://, return as is
    return website if website.start_with?("http://")

    # otherwise, prepend https://
    "https://#{website}"
  }

  def sponsor_image_path
    ["sponsors", slug].join("/")
  end

  def default_sponsor_image_path
    ["sponsors", "default"].join("/")
  end

  def sponsor_image_or_default_for(filename)
    sponsor_path = [sponsor_image_path, filename].join("/")
    default_path = [default_sponsor_image_path, filename].join("/")

    base = Rails.root.join("app", "assets", "images")

    return sponsor_path if (base / sponsor_path).exist?

    default_path
  end

  def sponsor_image_for(filename)
    sponsor_path = [sponsor_image_path, filename].join("/")

    Rails.root.join("app", "assets", "images", sponsor_image_path, filename).exist? ? sponsor_path : nil
  end

  def avatar_image_path
    sponsor_image_or_default_for("avatar.webp")
  end

  def banner_image_path
    sponsor_image_or_default_for("banner.webp")
  end

  def logo_image_path
    # First try local asset, then fallback to logo_url
    if sponsor_image_for("logo.webp")
      sponsor_image_or_default_for("logo.webp")
    elsif logo_url.present?
      logo_url
    else
      sponsor_image_or_default_for("logo.webp")
    end
  end

  def has_logo_image?
    sponsor_image_for("logo.webp").present? || logo_url.present?
  end
end
