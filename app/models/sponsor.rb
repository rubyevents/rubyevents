# == Schema Information
#
# Table name: sponsors
#
#  id              :integer          not null, primary key
#  description     :text
#  domain          :string
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
#  index_sponsors_on_slug  (slug)
#
class Sponsor < ApplicationRecord
  include Sluggable
  include UrlNormalizable

  slug_from :name

  # associations
  has_many :event_sponsors, dependent: :destroy
  has_many :events, through: :event_sponsors

  validates :name, presence: true, uniqueness: true

  before_save :ensure_unique_logo_urls

  normalize_url :website

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
