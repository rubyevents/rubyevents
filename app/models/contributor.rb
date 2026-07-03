# == Schema Information
#
# Table name: contributors
# Database name: primary
#
#  id         :integer          not null, primary key
#  avatar_url :string
#  html_url   :string
#  login      :string           not null, uniquely indexed
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          indexed
#
# Indexes
#
#  index_contributors_on_login    (login) UNIQUE
#  index_contributors_on_user_id  (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class Contributor < ApplicationRecord
  belongs_to :user, optional: true

  validates :login, presence: true, uniqueness: true

  def name
    return super if user_id.blank?

    user.name || super
  end
end
