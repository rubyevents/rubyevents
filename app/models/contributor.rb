class Contributor < ApplicationRecord
  belongs_to :user, optional: true

  validates :login, presence: true, uniqueness: true

  def name
    return super if user_id.blank?

    user.name || super
  end
end
