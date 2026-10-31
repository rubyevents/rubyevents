class SpeakersDirectory
  HIGHLIGHT_LIMIT = 12
  NEW_VOICES_WINDOW = 12.months
  SPEAKING_SOON_WINDOW = 60.days

  Highlight = Data.define(:speaker, :event, :date)

  def stats
    @stats ||= {
      speakers: speakers.count,
      active_this_year: speakers.joins(:kept_talks).where(talks: {date: Date.current.all_year}).distinct.count,
      new_this_year: first_talk_dates.count { |_, date| date.in?(Date.current.all_year) }
    }
  end

  def speaking_soon
    @speaking_soon ||= begin
      upcoming = speaker_talks
        .where(talks: {date: Date.current..SPEAKING_SOON_WINDOW.from_now.to_date})
        .merge(Talk.order(:date))
        .uniq(&:user_id)

      highlights_for(upcoming)
    end
  end

  def new_voices
    @new_voices ||= highlights_for(first_talks_between(NEW_VOICES_WINDOW.ago.to_date...Date.current).reverse)
  end

  def upcoming_debuts
    @upcoming_debuts ||= highlights_for(first_talks_between(Date.current..))
  end

  private

  def speakers
    User.speakers.canonical.where.not(name: Talk::StaticID::PLACEHOLDER_SPEAKER)
  end

  def speaker_talks
    UserTalk.dated.where(user: speakers).includes(:user, talk: :event)
  end

  def first_talk_dates
    @first_talk_dates ||= UserTalk.dated.where(user: speakers).group(:user_id).minimum("talks.date")
  end

  def first_talks_between(range)
    user_ids = first_talk_dates.select { |_, date| date.in?(range) }.keys

    speaker_talks.where(user_id: user_ids)
      .select { |user_talk| user_talk.talk.date == first_talk_dates[user_talk.user_id] }
      .uniq(&:user_id)
      .sort_by { |user_talk| user_talk.talk.date }
  end

  def highlights_for(user_talks)
    highlights = user_talks.map do |user_talk|
      Highlight.new(speaker: user_talk.user, event: user_talk.talk.event, date: user_talk.talk.date)
    end

    interleave_by_event(highlights).first(HIGHLIGHT_LIMIT)
  end

  def interleave_by_event(highlights)
    groups = highlights.group_by(&:event).values

    Array.new(groups.map(&:size).max.to_i) { |index| groups.filter_map { |group| group[index] } }.flatten
  end
end
