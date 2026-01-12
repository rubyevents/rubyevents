# == Schema Information
#
# Table name: favorite_users
# Database name: primary
#
#  id               :integer          not null, primary key
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  favorite_user_id :integer          not null, indexed
#  user_id          :integer          not null, indexed
#
# Indexes
#
#  index_favorite_users_on_favorite_user_id  (favorite_user_id)
#  index_favorite_users_on_user_id           (user_id)
#
# Foreign Keys
#
#  favorite_user_id  (favorite_user_id => users.id)
#  user_id           (user_id => users.id)
#
class FavoriteUser < ApplicationRecord
  belongs_to :user
  belongs_to :favorite_user, class_name: "User"

  validates :user, comparison: {other_than: :favorite_user}
end
