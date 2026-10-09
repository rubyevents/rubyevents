class User::Languages < ActiveRecord::AssociatedObject
  # Each language maps to a hash of dimensions, e.g. {"understands" => true}.
  # Only "understands" is used so far; nesting means "speaks" (etc.) can be added
  # later without a migration.
  DIMENSIONS = %w[understands].freeze

  extension do
    validate do
      valid = language_preferences.all? do |_code, entry|
        entry.is_a?(Hash) &&
          (entry.keys - User::Languages::DIMENSIONS).empty? &&
          entry.values.all? { |value| [true, false].include?(value) }
      end

      errors.add(:language_preferences, "has an invalid shape") unless valid
    end
  end

  def understands?(code)
    dimension(code, "understands") == true
  end

  def does_not_understand?(code)
    dimension(code, "understands") == false
  end

  def set?(code)
    preferences.key?(code.to_s)
  end

  def understood
    codes_where("understands", true)
  end

  def not_understood
    codes_where("understands", false)
  end

  def set(code, answer)
    value = case answer.to_s
    when "understands" then true
    when "does_not_understand" then false
    when "unset" then nil
    else raise ArgumentError, "unknown language preference answer: #{answer}"
    end

    entry = (preferences[code.to_s] || {}).dup
    value.nil? ? entry.delete("understands") : entry["understands"] = value

    updated = preferences.merge(code.to_s => entry)
    updated.delete(code.to_s) if entry.empty?

    user.update(language_preferences: updated)
  end

  def pending_prompts
    given = given_counts
    watched = watched_counts

    codes = (given.keys + watched.keys).compact.uniq.reject { |code| understanding_set?(code) }

    codes.map { |code|
      if given[code].to_i.positive?
        {code: code, source: :given, count: given[code]}
      else
        {code: code, source: :watched, count: watched[code].to_i}
      end
    }.sort_by { |prompt| [(prompt[:source] == :given) ? 0 : 1, -prompt[:count]] }
  end

  def pending_prompt
    pending_prompts.first
  end

  def watched_counts
    user.watched_talks.joins(:talk).group("talks.language").count
  end

  def given_counts
    user.talks.where.not(language: nil).group(:language).count
  end

  private

  def understanding_set?(code)
    !dimension(code, "understands").nil?
  end

  def dimension(code, name)
    preferences.dig(code.to_s, name)
  end

  def codes_where(name, value)
    preferences.select { |_, entry| entry[name] == value }.keys
  end

  def preferences
    user.language_preferences
  end
end
