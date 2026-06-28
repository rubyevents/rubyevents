class NewsletterGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  class_option :year, type: :string, default: Time.now.year.to_s, desc: "Year for the newsletter"

  def create_newsletter_file
    @month = name.capitalize
    @year = options[:year]
    @first_day_of_month = Date.new(@year.to_i, Date::MONTHNAMES.index(@month), 1)
    @last_day_of_month = @first_day_of_month.end_of_month
    @github_date_range = "#{@first_day_of_month.iso8601}..#{@last_day_of_month.iso8601}"
    # Newsletter releases on the first day of the next month.
    @newsletter_date = @first_day_of_month.next_month

    @next_month = @newsletter_date.strftime("%B")

    @cfps = CFP.where("close_date >= ?", @newsletter_date).order(:close_date)

    @this_month_events = Event.where(start_date: @first_day_of_month..@last_day_of_month).or(Event.where(end_date: @first_day_of_month..@last_day_of_month)).order(:start_date)

    @next_month_events = Event.where(start_date: @newsletter_date..@newsletter_date.end_of_month).or(Event.where(end_date: @newsletter_date..@newsletter_date.end_of_month)).order(:start_date)

    filename = "#{@newsletter_date}-#{@month.downcase}-newsletter.md"
    @filepath = File.join("content", "announcements", filename)

    template "template.md.tt", @filepath
  end

  private

  def event_dates_in_sentence(event)
    if event.start_date == event.end_date
      "on #{event.formatted_dates}"
    else
      "from #{event.formatted_dates}"
    end.gsub(/, #{@year}/, "")
  end
end
