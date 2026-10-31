User::SpeakingActivity = Data.define(:first_year, :last_year, :latest_event) do
  def self.for(users)
    talks_by_user = UserTalk.dated.where(user_id: users.map(&:id)).includes(talk: :event).group_by(&:user_id)

    talks_by_user.transform_values do |user_talks|
      talks = user_talks.map(&:talk)
      latest_talk = talks.select { |talk| talk.date <= Date.current }.max_by(&:date)

      new(
        first_year: talks.map(&:date).min.year,
        last_year: talks.map(&:date).max.year,
        latest_event: latest_talk&.event
      )
    end
  end
end
