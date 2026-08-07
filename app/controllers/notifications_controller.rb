# frozen_string_literal: true

class NotificationsController < ApplicationController
  def index
    set_meta_tags(title: "Notifications")
    @notifications = Current.user.notification_users.includes(:notification).order(created_at: :desc)
  end

  def redirect
    notification_user = NotificationUser.find(params[:id])
    notification_user.update(read: true)
    redirect_to notification_user.to_link
  end
end
