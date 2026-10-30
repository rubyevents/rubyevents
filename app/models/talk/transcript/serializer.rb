class Talk::Transcript::Serializer
  def self.dump(cue_list)
    raise "Transcript is not a valid object" unless cue_list.is_a?(Talk::Transcript::CueList)

    cue_list.cues.map(&:to_h).to_json
  end

  def self.load(cue_list_json)
    return Talk::Transcript::CueList.new(cues: []) if cue_list_json.nil? || cue_list_json.empty?

    cues = JSON.parse(cue_list_json, symbolize_names: true).map do |cue_hash|
      Talk::Transcript::Cue.new(start_time: cue_hash[:start_time], end_time: cue_hash[:end_time], text: cue_hash[:text])
    end

    Talk::Transcript::CueList.new(cues:)
  end
end
