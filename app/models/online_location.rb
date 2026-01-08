# frozen_string_literal: true

class OnlineLocation
  include ActiveModel::Model
  include ActiveModel::Attributes

  def name
    "Online"
  end

  def slug
    "online"
  end

  def emoji_flag
    "🌐"
  end

  def path
    Router.online_path
  end

  def past_path
    Router.online_past_index_path
  end

  def events
    Event.not_geocoded.includes(:series)
  end

  def users
    User.none
  end

  def stamps
    []
  end

  def events_count
    events.count
  end

  def users_count
    0
  end

  def geocoded?
    false
  end

  def coordinates
    nil
  end

  def to_coordinates
    nil
  end

  def bounds
    nil
  end

  class << self
    def instance
      @instance ||= new
    end
  end
end
