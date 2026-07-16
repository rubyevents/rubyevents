class LanguagePreferencesController < ApplicationController
  ANSWERS = %w[understands does_not_understand unset].freeze

  # PATCH /language_preference
  def update
    code = params[:language_code].to_s
    answer = params[:answer].to_s

    if code.present? && ANSWERS.include?(answer)
      Current.user.languages.set(code, answer)
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end
end
