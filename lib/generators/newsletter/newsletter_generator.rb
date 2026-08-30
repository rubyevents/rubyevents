class NewsletterGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  class_option :year, type: :string, default: Time.now.year.to_s, desc: "Year for the newsletter"

  VIDEO_FILE_REGEX = %r{data/(?<event_series>[^/]+)/(?<event_name>[^/]+)/videos\.yml}

  def initialize_dates
    @month = name.capitalize
    @year = options[:year]
    @first_day_of_month = Date.new(@year.to_i, Date::MONTHNAMES.index(@month), 1)
    @last_day_of_month = @first_day_of_month.end_of_month
    @github_date_range = "#{@first_day_of_month.iso8601}..#{@last_day_of_month.iso8601}"
    # Newsletter releases on the first day of the next month.
    @newsletter_date = @first_day_of_month.next_month

    @next_month = @newsletter_date.strftime("%B")
  end

  def fetch_this_months_contributions
    @pull_requests = JSON.parse(%x(
      gh pr list --repo RubyEvents/RubyEvents --limit 150 \
        --state merged --search "merged:#{@github_date_range}" \
        --json author,number,url,labels
    ))
    @pr_count = @pull_requests.size
    contributors = @pull_requests.group_by { |pr| pr["author"] }
      .sort_by { |author, prs| prs.size }
      .reverse
    @contributor_list = contributors.map do |author, prs|
      (author["login"] == "app/copilot-swe-agent") ? "🤖" : "#{author["name"]}(@#{author["login"]})"
    end.to_sentence
    @contributors_count = contributors.size
    @content_pr_count = @pull_requests.count { |pr| pr["labels"]&.any? { |label| label["name"] == "content" } }
  end

  # Relies on the PRs from fetching contributions
  def fetch_videos
    video_prs = @pull_requests.filter { |pr| pr["labels"]&.any? { |label| label["name"] == "videos" } }.map { |pr| pr["number"] }
    @video_prs_update_event = {}
    video_prs.each do |pr_number|
      video_files = `gh pr diff --name-only #{pr_number}`.split("\n").select { |file| file.ends_with?("videos.yml") }
      updated_events = video_files.map do |file|
        match = file.match(VIDEO_FILE_REGEX)
        match ? "/events/#{match[:event_name]}/talks" : nil
      end.compact.uniq
      @video_prs_update_event[pr_number] = updated_events
    end
  end

  def create_newsletter_file
    @cfps = CFP.where("close_date >= ?", @newsletter_date).order(:close_date)

    @this_month_events = Event.where(start_date: @first_day_of_month..@last_day_of_month).or(Event.where(end_date: @first_day_of_month..@last_day_of_month)).order(:start_date)

    @next_month_events = Event.where(start_date: @newsletter_date..@newsletter_date.end_of_month).or(Event.where(end_date: @newsletter_date..@newsletter_date.end_of_month)).order(:start_date)

    filename = "#{@newsletter_date}-#{@month.downcase}-newsletter.md"
    @filepath = File.join("content", "announcements", filename)

    template "template.md.tt", @filepath
  end
end
