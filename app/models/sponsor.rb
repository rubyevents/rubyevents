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

  configure_slug(attribute: :name, auto_suffix_on_collision: false)

  # associations
  has_many :event_sponsors, dependent: :destroy
  has_many :events, through: :event_sponsors
  has_many :event_involvements, as: :involvementable, dependent: :destroy
  has_many :involved_events, through: :event_involvements, source: :event

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
    if sponsor_image_for("avatar.webp")
      sponsor_image_or_default_for("avatar.webp")
    else
      generate_avatar_url
    end
  end

  def banner_image_path
    sponsor_image_or_default_for("banner.webp")
  end

  def generate_avatar_url(size: 200)
    url_safe_initials = name.split(" ").map(&:first).join("")

    "https://ui-avatars.com/api/?name=#{url_safe_initials}&size=#{size}&background=f3f4f6&color=4b5563&font-size=0.4&length=2"
  end

  def logo_image_path
    if sponsor_image_for("logo.webp")
      sponsor_image_or_default_for("logo.webp")
    elsif logo_url.present? && logo_url_accessible?
      logo_url
    else
      avatar_image_path
    end
  end

  def has_logo_image?
    sponsor_image_for("logo.webp").present? || (logo_url.present? && logo_url_accessible?)
  end

  def logo_url_accessible?
    return false unless logo_url.present?

    begin
      uri = URI.parse(logo_url)
      return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.open_timeout = 5
        http.read_timeout = 10
        http.head(uri.path.empty? ? "/" : uri.path)
      end

      response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
    rescue
      false
    end
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
