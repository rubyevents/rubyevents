class Speakers::SocialProfilesController < ::SocialProfilesController
  prepend_before_action :set_sociable

  private

  def set_sociable
    @sociable ||= Speaker.find_by!(slug: params[:speaker_slug])
  end
end
