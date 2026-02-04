module LocaleHelper
  def current_locale_flag
    case I18n.locale
    when :ja then "🇯🇵"
    else "🇺🇸"
    end
  end

  def locale_switch_url(locale)
    url_for(request.path_parameters.merge(request.query_parameters).merge(locale: locale))
  end
end
