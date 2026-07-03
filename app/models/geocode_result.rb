# == Schema Information
#
# Table name: geocode_results
# Database name: primary
#
#  id            :integer          not null, primary key
#  query         :string           not null, uniquely indexed
#  response_body :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_geocode_results_on_query  (query) UNIQUE
#
class GeocodeResult < ApplicationRecord
  validates :query, presence: true, uniqueness: true
end
