# == Schema Information
#
# Table name: sponsors
#
#  id          :integer          not null, primary key
#  description :text
#  logo_url    :string
#  name        :string
#  slug        :string           indexed
#  website     :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_sponsors_on_slug  (slug)
#
class Sponsor < ApplicationRecord
  include Sluggable
  slug_from :name

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
end
