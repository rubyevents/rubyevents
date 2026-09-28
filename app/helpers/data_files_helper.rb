module DataFilesHelper
  EVENT_PAGE_DATA_FILES = {
    "events" => "event.yml",
    "events/venues" => "venue.yml",
    "events/schedules" => "schedule.yml",
    "events/sponsors" => "sponsors.yml",
    "events/cfp" => "cfp.yml",
    "events/involvements" => "involvements.yml",
    "events/videos" => "videos.yml",
    "events/talks" => "videos.yml",
    "events/speakers" => "videos.yml",
    "events/participants" => "videos.yml"
  }.freeze

  def current_event_data_file(path = controller.controller_path)
    EVENT_PAGE_DATA_FILES.fetch(path, "event.yml")
  end

  def data_file_link_for(record, file: nil, label: nil)
    return unless Rails.env.development?

    path = data_file_path_for(record, file: file)
    return if path.blank?

    basename = File.basename(path)

    unless File.exist?(Rails.root.join(path))
      return ui_tooltip("#{path} doesn't exist yet", class: "inline-flex") do
        content_tag(:span, "#{basename} (missing)", class: "btn btn-xs btn-ghost btn-disabled font-mono normal-case text-gray-400")
      end
    end

    url = editor_url_for(path, line: data_file_line_for(record, path))
    return if url.blank?

    ui_tooltip("Open #{path} in your editor", class: "inline-flex") do
      link_to url, class: "btn btn-xs btn-ghost gap-1 font-mono normal-case", data: {turbo: false} do
        safe_join([fa("code"), content_tag(:span, label || basename)])
      end
    end
  end

  def data_file_path_for(record, file: nil)
    case record
    when Event
      dir = event_data_directory(record)
      dir && File.join(dir, file || "event.yml")
    when EventSeries
      Static::EventSeries.find_by_slug(record.slug)&.__file_path
    when Talk
      return if record.event.blank?

      data_file_path_for(record.event, file: file || "videos.yml")
    end
  end

  def editor_url_for(repo_relative_path, line: 1)
    editor = ActiveSupport::Editor.current || ActiveSupport::Editor.find("vscode")
    return if editor.blank?

    editor.url_for(Rails.root.join(repo_relative_path).to_s, line)
  end

  def data_file_line_for(record, path)
    case record
    when Talk
      videos_file_entry_line(path, id: record.static_id)
    else
      1
    end
  end

  private

  def videos_file_entry_line(repo_relative_path, id:)
    return 1 if id.blank?

    absolute = Rails.root.join(repo_relative_path)
    return 1 unless File.exist?(absolute)

    Static::VideosFile.new(absolute.to_s).find_by(id: id)&.line || 1
  rescue => e
    Rails.logger.debug { "videos.yml line lookup failed for #{repo_relative_path} (#{id}): #{e.message}" }

    1
  end

  def event_data_directory(event)
    static = Static::Event.find_by_slug(event.slug)
    return if static&.__file_path.blank?

    File.dirname(static.__file_path)
  end
end
