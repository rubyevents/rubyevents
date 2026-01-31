module Localizable
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
  end

  private

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  protected

  def default_url_options
    super.merge(locale: locale_in_url.to_s)
  end

  def locale_in_url
    (I18n.locale == I18n.default_locale) ? nil : I18n.locale
  end
end
