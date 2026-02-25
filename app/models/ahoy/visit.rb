# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: ahoy_visits
# Database name: primary
#
#  id               :integer          not null, primary key
#  app_version      :string
#  browser          :string
#  city             :string
#  country          :string
#  device_type      :string
#  ip               :string           indexed, indexed => [started_at]
#  landing_page     :text
#  latitude         :float
#  longitude        :float
#  os               :string
#  os_version       :string
#  platform         :string
#  referrer         :text
#  referring_domain :string
#  region           :string
#  started_at       :datetime         indexed => [ip]
#  user_agent       :text
#  utm_campaign     :string
#  utm_content      :string
#  utm_medium       :string
#  utm_source       :string
#  utm_term         :string
#  visit_token      :string           uniquely indexed
#  visitor_token    :string
#  user_id          :integer          indexed
#
# Indexes
#
#  index_ahoy_visits_on_ip                 (ip)
#  index_ahoy_visits_on_started_at_and_ip  (started_at,ip)
#  index_ahoy_visits_on_user_id            (user_id)
#  index_ahoy_visits_on_visit_token        (visit_token) UNIQUE
#
# rubocop:enable Layout/LineLength
class Ahoy::Visit < ApplicationRecord
  self.table_name = "ahoy_visits"

  include Rollupable

  rollup_default_column :started_at

  has_many :events, class_name: "Ahoy::Event", dependent: :destroy
  belongs_to :user, optional: true
end
