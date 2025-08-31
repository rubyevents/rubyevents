require "test_helper"

class WatchedTalkTest < ActiveSupport::TestCase
  test "update_progress! method marks as completed when reaching 90%" do
    talk = talks(:one)
    watched_talk = watched_talks(:one)

    talk.update!(duration_in_seconds: 1000)
    watched_talk.update!(completed: false)

    watched_talk.update!(progress_seconds: 500)

    assert_not watched_talk.completed?

    watched_talk.update_progress!(900)

    assert watched_talk.completed?
  end

  test "update_progress! method does not mark as completed when below 90%" do
    talk = talks(:one)
    watched_talk = watched_talks(:one)

    talk.update!(duration_in_seconds: 1000)
    watched_talk.update!(completed: false)
    
    watched_talk.update!(progress_seconds: 0)

    watched_talk.update_progress!(850)

    assert_not watched_talk.completed?
  end
end
