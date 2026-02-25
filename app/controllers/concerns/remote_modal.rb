module RemoteModal
  extend ActiveSupport::Concern
  include Turbo::ForceResponse

  included do
    layout :define_layout
    helper_method :modal_options
  end

  class_methods do
    def respond_with_remote_modal(options = {})
      before_action :enable_remote_modal, **options
      force_frame_response(**options)
    end
  end

  private

  def enable_remote_modal
    @remote_modal = true
  end

  def modal_options
    @modal_options ||= {}
  end

  def set_modal_options(options)
    @modal_options = options
  end

  def define_layout
    return "modal" if turbo_frame_request_id == "modal" && @remote_modal

    "application"
  end
end
