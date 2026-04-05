# frozen_string_literal: true

class NotificationsController < ApplicationController
  def index
    set_meta_tags(title: "Notifications")
    @notifications = Current.user.notification_users.includes(:notification).order(created_at: :desc)
  end
end
