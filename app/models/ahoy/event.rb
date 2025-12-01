# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: ahoy_events
# Database name: primary
#
#  id         :integer          not null, primary key
#  name       :string           indexed => [time]
#  properties :text
#  time       :datetime         indexed => [name]
#  user_id    :integer          indexed
#  visit_id   :integer          indexed
#
# Indexes
#
#  index_ahoy_events_on_name_and_time  (name,time)
#  index_ahoy_events_on_user_id        (user_id)
#  index_ahoy_events_on_visit_id       (visit_id)
#
# rubocop:enable Layout/LineLength
class Ahoy::Event < ApplicationRecord
  include Ahoy::QueryMethods

  self.table_name = "ahoy_events"
  include Rollupable

  rollup_default_column :time

  belongs_to :visit
  belongs_to :user, optional: true

  serialize :properties, coder: JSON
end
