class Static::Validators::Validator
  def self.cfp_validator_classes
    @cfp_validators ||= [
      Static::Validators::Schema
    ]
  end

  def self.event_validator_classes
    @event_validators ||= [
      Static::Validators::Schema,
      Static::Validators::AssetsHaveColors,
      Static::Validators::ColorsHaveAssets,
      Static::Validators::DuplicateYouTubeChannels,
      Static::Validators::EventCityNames,
      Static::Validators::EventDates,
      Static::Validators::EventRecordingsPublishedDate,
      Static::Validators::IdMatchesFolder,
      Static::Validators::RemovedTalkIds,
      Static::Validators::SeriesDefaultColors
    ]
  end

  def self.involvement_validator_classes
    @involvement_validators ||= [
      Static::Validators::Schema,
      Static::Validators::InvolvementRoleName
    ]
  end

  def self.schedule_validator_classes
    @schedule_validators ||= [
      Static::Validators::Schema,
      Static::Validators::ScheduleSlotsFilled
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
      Static::Validators::SpeakerSlugMatchesName,
      Static::Validators::UniqueSpeakerFields,
      Static::Validators::UniqueSpeakers
    ]
  end

  def self.sponsor_validator_classes
    @sponsor_validators ||= [
      Static::Validators::Schema,
      Static::Validators::SponsorSlug
    ]
  end

  def self.venue_validator_classes
    @venue_validators ||= [
      Static::Validators::Schema
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
      Static::Validators::UniqueTalkIds,
      Static::Validators::MissingThumbnails
    ]
  end

  # Registered validators that can fix themselves. `fix` is an instance method, so a
  # class never responds to it and the check has to be method_defined?. New scopes
  # have to be added here.
  def self.fixable_validators
    [
      cfp_validator_classes,
      event_validator_classes,
      involvement_validator_classes,
      schedule_validator_classes,
      series_validator_classes,
      speaker_validator_classes,
      sponsor_validator_classes,
      venue_validator_classes,
      video_validator_classes
    ].flatten.uniq.select { |validator_class| validator_class.method_defined?(:fix) }
  end
end
