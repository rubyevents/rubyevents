class Language
  DEFAULT = "en".freeze
  ALL_ALPHA2_CODES = ISO_639::ISO_639_1.map(&:alpha2).freeze
  ALL_ENGLISH_NAMES = ISO_639::ISO_639_1.map { |language| language.english_name.split(";").first }.freeze
  ALL_LANGUAGES = ALL_ALPHA2_CODES.zip(ALL_ENGLISH_NAMES).to_h.freeze

  def self.find(term)
    ISO_639
      .search(term)
      .reject { |result| result.alpha2.blank? }
      .first
  end

  def self.find_by_code(code)
    ISO_639.find_by_code(code)
  end

  def self.alpha2_codes
    ALL_ALPHA2_CODES
  end

  def self.english_names
    ALL_ENGLISH_NAMES
  end

  def self.all
    ALL_LANGUAGES
  end

  def self.by_code(code)
    ALL_LANGUAGES[code]
  end

  def self.used
    assigned_languages = Talk.distinct.pluck(:language)

    Language.all.dup.keep_if { |key, value| assigned_languages.include?(key) }
  end

  def self.talks(code)
    Talk.where(language: code)
  end

  def self.talks_count(code)
    Talk.where(language: code).count
  end

  def self.native_name(code)
    LanguageHelper::NATIVE_NAMES[code]
  end

  def self.emoji_flag(code)
    name = by_code(code)
    return "🏳️" unless name

    LanguageHelper::LANGUAGE_TO_EMOJI[name.downcase] || "🏳️"
  end

  def self.synonyms_for(code)
    record = find_by_code(code)
    return [] unless record

    synonyms = []

    synonyms << record.alpha3_bibliographic if record.alpha3_bibliographic.present?
    synonyms << record.alpha3 if record.alpha3.present? && record.alpha3 != record.alpha3_bibliographic

    if record.english_name.present?
      record.english_name.split(";").each do |name|
        synonyms << name.strip.downcase
      end
    end

    if record.french_name.present?
      record.french_name.split(";").each do |name|
        synonyms << name.strip.downcase
      end
    end

    synonyms << LanguageHelper::NATIVE_NAMES[code] if LanguageHelper::NATIVE_NAMES[code].present?

    synonyms.uniq
  end

  def self.all_synonyms
    used.keys.each_with_object({}) do |code, hash|
      synonyms = synonyms_for(code)
      next if synonyms.empty?

      all_terms = [code] + synonyms

      hash["#{code}-language-synonym"] = {"synonyms" => all_terms.uniq}
    end
  end
end
