class Static::Validators::Validator
  def self.event_validator_classes
    @event_validators ||= [
      Static::Validators::Schema,
      Static::Validators::ColorsHaveAssets,
      Static::Validators::DuplicateYouTubeChannels,
      Static::Validators::EventCityNames,
      Static::Validators::EventDates,
      Static::Validators::EventRecordingsPublishedDate,
      Static::Validators::IdMatchesFolder,
      Static::Validators::SeriesDefaultColors
    ]
  end

  def self.series_validator_classes
    @series_validators ||= [
      Static::Validators::Schema,
      Static::Validators::IdMatchesFolder
    ]
  end

  def self.speaker_validator_classes
    @speaker_validators ||= [
      Static::Validators::Schema,
      Static::Validators::SimilarSpeakerNames,
      Static::Validators::UniqueSpeakerFields,
      Static::Validators::UniqueSpeakers
    ]
  end

  def self.video_validator_classes
    @video_validators ||= [
      Static::Validators::Schema,
      Static::Validators::SpeakerExists,
      Static::Validators::SpeakersOrTalks,
      Static::Validators::TalkDates,
      Static::Validators::TalkId,
      Static::Validators::TalkKind,
      Static::Validators::TalkLanguage,
      Static::Validators::TalkPublishedAt,
      Static::Validators::TalkRenames,
      Static::Validators::TalkShortKind,
      Static::Validators::UniqueTalkIds
    ]
  end

  def self.involvement_validator_classes
    @involvement_validators ||= [
      Static::Validators::Schema,
      Static::Validators::InvolvementRoleName
    ]
  end
end
