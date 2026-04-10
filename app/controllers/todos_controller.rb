class TodosController < ApplicationController
  include Pagy::Backend

  skip_before_action :authenticate_user!

  def index
    @view = params[:view].presence || "by_type"
    @todos = Todo.all

    case @view
    when "by_type"
      @todos_by_type = group_by_type(@todos)
      @pagy, @todos_by_type = pagy_array(@todos_by_type, limit: 25)
    else
      @series_with_todos = group_by_series(@todos)
      @series_with_todos = @series_with_todos.sort_by do |series_data|
        [-series_data[:total_count], series_data[:series]&.name || "zzz"]
      end
      @pagy, @series_with_todos = pagy_array(@series_with_todos, limit: 25)
    end
  end

  private

  def group_by_type(matches)
    grouped = matches.group_by(&:normalized_content)

    grouped.map do |normalized_content, type_matches|
      {
        normalized_content: normalized_content.presence || "TODO",
        example_content: type_matches.first.content,
        matches: type_matches.sort_by(&:file),
        count: type_matches.size
      }
    end.sort_by { |t| -t[:count] }
  end

  def group_by_series(todos)
    grouped = todos.group_by(&:series_slug)

    grouped.map do |series_slug, series_todos|
      series = Static::EventSeries.find_by_slug(series_slug)

      events = series_todos.group_by(&:event_slug)

      events_data = events.map do |event_slug, event_todos|
        event = event_slug ? Static::Event.find_by_slug(event_slug) : nil
        files = event_todos.group_by(&:file)

        {
          event_slug: event_slug,
          event: event,
          files: files,
          total_count: event_todos.size
        }
      end.sort_by do |e|
        [
          e[:event]&.end_date ? 0 : 1,
          e[:event]&.end_date ? -e[:event].end_date.to_time.to_i : 0
        ]
      end

      {
        series_slug: series_slug,
        series: series,
        events: events_data,
        total_count: series_todos.size
      }
    end
  end
end
