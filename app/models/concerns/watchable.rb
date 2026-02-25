module Watchable
  extend ActiveSupport::Concern

  included do
    has_many :watched_talks, dependent: :destroy
  end

  def mark_as_watched!
    watched_talks.find_or_create_by!(user: Current.user)
  end

  def unmark_as_watched!
    watched_talks.find_by(user: Current.user)&.destroy!
  end

  def watched?(user = Current.user)
    watched_talks.exists?(user: user)
  end
end
