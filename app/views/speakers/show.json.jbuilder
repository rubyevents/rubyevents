json.speaker do
  json.partial! "speakers/speaker", speaker: @speaker
  json.talks @talks do |talk|
    json.partial! "talks/talk", talk: talk
  end
end
