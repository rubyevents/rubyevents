module RequestedTalkTopicsHelper
  def requested_talk_topic_status_options
    [["All Statuses", ""]] +
      RequestedTalkTopic.statuses.keys.map do |status|
        [status.titleize, status]
      end
  end

  def requested_talk_topic_sort_options
    [
      ["Trending", "votes"],
      ["Newest", "newest"],
      ["Oldest", "oldest"],
      ["Least Votes", "least_votes"]
    ]
  end
end
