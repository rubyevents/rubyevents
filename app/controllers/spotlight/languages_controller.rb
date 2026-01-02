class Spotlight::LanguagesController < ApplicationController
  LIMIT = 10

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    @languages = search_languages(search_query)
    @total_count = @languages.size

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  helper_method :search_query
  def search_query
    params[:s].presence
  end

  helper_method :total_count
  attr_reader :total_count

  def search_languages(query)
    return [] if query.blank?

    results = []
    query_downcase = query.downcase

    languages_with_talks.each do |language_code, talk_count|
      language_name = Language.by_code(language_code)
      next unless language_name

      if language_name.downcase.include?(query_downcase) ||
          language_code.downcase.include?(query_downcase)
        results << {
          code: language_code,
          name: language_name,
          talk_count: talk_count,
          path: talks_path(language: language_code)
        }
      end
    end

    results.sort_by do |r|
      exact_match = (r[:name].downcase == query_downcase) ? 0 : 1
      starts_with = r[:name].downcase.start_with?(query_downcase) ? 0 : 1
      [exact_match, starts_with, -r[:talk_count]]
    end.first(LIMIT)
  end

  def languages_with_talks
    @languages_with_talks ||= Talk.where.not(language: [nil, "", "en"])
      .group(:language)
      .count
  end
end
