class Insights::TalksController < ApplicationController
  skip_before_action :authenticate_user!

  def durations
    data = Rails.cache.fetch("insights:talks:durations", expires_in: 1.hour) do
      buckets = [
        {min: 0, max: 5, label: "< 5 min"},
        {min: 5, max: 15, label: "5-15 min"},
        {min: 15, max: 30, label: "15-30 min"},
        {min: 30, max: 45, label: "30-45 min"},
        {min: 45, max: 60, label: "45-60 min"},
        {min: 60, max: 90, label: "60-90 min"},
        {min: 90, max: 9999, label: "> 90 min"}
      ]

      talks_with_duration = Talk.where.not(duration_in_seconds: [nil, 0])

      buckets.map do |bucket|
        count = talks_with_duration
          .where("duration_in_seconds >= ? AND duration_in_seconds < ?", bucket[:min] * 60, bucket[:max] * 60)
          .count
        {label: bucket[:label], count: count, minutes_min: bucket[:min], minutes_max: bucket[:max]}
      end
    end

    render json: data
  end

  def kinds
    data = Rails.cache.fetch("insights:talks:kinds", expires_in: 1.hour) do
      Talk.group(:kind).count.map do |kind, count|
        {kind: kind || "unknown", label: (kind || "unknown").to_s.titleize.tr("_", " "), count: count}
      end.sort_by { |d| -d[:count] }
    end

    render json: data
  end

  def languages
    data = Rails.cache.fetch("insights:talks:languages", expires_in: 1.hour) do
      Talk.where.not(language: [nil, ""])
        .group(:language)
        .count
        .map do |code, count|
          lang_name = Language.by_code(code)
          {code: code, name: lang_name || code, count: count}
        end
        .sort_by { |d| -d[:count] }
    end

    render json: data
  end

  def title_words
    data = Rails.cache.fetch("insights:talks:title_words", expires_in: 6.hours) do
      stopwords = %w[a an the and or but in on at to for of with is are was were be been being have has had do does did will would could should may might must shall can cannot into from by as this that these those it its]

      word_counts = Hash.new(0)

      Talk.pluck(:title).each do |title|
        next if title.blank?

        words = title.downcase.gsub(/[^a-z0-9\s]/, "").split(/\s+/)
        words.each do |word|
          next if word.length < 3
          next if stopwords.include?(word)
          next if word.match?(/^\d+$/)

          word_counts[word] += 1
        end
      end

      word_counts
        .sort_by { |_, count| -count }
        .first(100)
        .map { |word, count| {text: word, value: count} }
    end

    render json: data
  end

  def duration_trends
    data = Rails.cache.fetch("insights:talks:duration_trends", expires_in: 1.hour) do
      Talk
        .where.not(date: nil)
        .where.not(duration_in_seconds: [nil, 0])
        .where("duration_in_seconds > 0 AND duration_in_seconds < 10800")
        .group(Arel.sql("strftime('%Y', date)"))
        .order(Arel.sql("strftime('%Y', date)"))
        .pluck(Arel.sql("strftime('%Y', date), AVG(duration_in_seconds), COUNT(*)"))
        .map do |year, avg_seconds, count|
          {year: year, avg_minutes: (avg_seconds / 60.0).round(1), count: count}
        end
    end

    render json: data
  end

  def providers
    data = Rails.cache.fetch("insights:talks:providers", expires_in: 1.hour) do
      Talk.group(:video_provider).count.map do |provider, count|
        {provider: provider || "unknown", count: count}
      end.sort_by { |d| -d[:count] }
    end

    render json: data
  end
end
