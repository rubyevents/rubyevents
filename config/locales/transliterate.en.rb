# frozen_string_literal: true

approximations = {
  # German umlauts
  "ü" => "ue", "ö" => "oe", "ä" => "ae", "ß" => "ss", "ÿ" => "y",

  # Cyrillic characters (lowercase)
  "а" => "a", "б" => "b", "в" => "v", "г" => "g", "д" => "d", "е" => "e",
  "ё" => "yo", "ж" => "zh", "з" => "z", "и" => "i", "й" => "y", "к" => "k",
  "л" => "l", "м" => "m", "н" => "n", "о" => "o", "п" => "p", "р" => "r",
  "с" => "s", "т" => "t", "у" => "u", "ф" => "f", "х" => "h", "ц" => "ts",
  "ч" => "ch", "ш" => "sh", "щ" => "sch", "ъ" => "", "ы" => "y", "ь" => "",
  "э" => "e", "ю" => "yu", "я" => "ya",

  # Cyrillic characters (uppercase)
  "А" => "A", "Б" => "B", "В" => "V", "Г" => "G", "Д" => "D", "Е" => "E",
  "Ё" => "Yo", "Ж" => "Zh", "З" => "Z", "И" => "I", "Й" => "Y", "К" => "K",
  "Л" => "L", "М" => "M", "Н" => "N", "О" => "O", "П" => "P", "Р" => "R",
  "С" => "S", "Т" => "T", "У" => "U", "Ф" => "F", "Х" => "H", "Ц" => "Ts",
  "Ч" => "Ch", "Ш" => "Sh", "Щ" => "Sch", "Ъ" => "", "Ы" => "Y", "Ь" => "",
  "Э" => "E", "Ю" => "Yu", "Я" => "Ya"
}

transliterator = I18n::Backend::Transliterator::HashTransliterator.new(approximations)

# Characters missing from the approximations fall back to their decomposed form without accents, so "ế" becomes "e" and "³" becomes "3"
transliterate = lambda do |string|
  string.each_char.map do |character|
    transliterated = transliterator.transliterate(character, "?")
    next transliterated unless transliterated == "?" && character != "?"

    transliterator.transliterate(character.unicode_normalize(:nfkd).gsub(/\p{Mn}/, ""), "?")
  end.join
end

{en: {i18n: {transliterate: {rule: transliterate}}}}
