class Static::Validators::Validator
  def self.event_validator_classes
    @event_validators ||= [
      Static::Validators::Schema,
      Static::Validators::ColorsHaveAssets,
      Static::Validators::DuplicateYouTubeChannels,
      Static::Validators::EventCityNames,
      Static::Validators::EventDates,
      Static::Validators::EventRecordingsPublishedDate
    ]
  end

  def self.speaker_validator_classes
    @speaker_validators ||= [
      Static::Validators::SchemaArray,
      Static::Validators::UniqueSpeakerFields,
      Static::Validators::UniqueSpeakers
    ]
  end

  def self.video_validator_classes
    @video_validators ||= [
      Static::Validators::SchemaArray,
      Static::Validators::SpeakerExists,
      Static::Validators::SpeakersOrTalks,
      Static::Validators::TalkDates,
      Static::Validators::TalkKind,
      Static::Validators::TalkPublishedAt,
      Static::Validators::TalkShortKind
    ]
  end
end
