# frozen_string_literal: true

require "json"

module Import
  module TUI
    class << self
      def run
        puts "Loading static data…"

        series = Static::EventSeries.all.sort_by { |entry| entry.slug.to_s }
        Static::Event.all

        imported_series = Set.new(::EventSeries.pluck(:slug))
        imported_events = Set.new(::Event.pluck(:slug))

        events_pipe_read, events_pipe_write = IO.pipe
        commands_pipe_read, commands_pipe_write = IO.pipe

        worker_pid = fork do
          Process.setpgid(0, 0)
          Signal.trap("TERM") { exit!(0) }
          events_pipe_read.close
          commands_pipe_write.close

          Worker.new(commands_pipe_read, events_pipe_write).loop
        end

        begin
          Process.setpgid(worker_pid, worker_pid)
        rescue Errno::EACCES, Errno::ESRCH, Errno::EPERM
          nil
        end

        events_pipe_write.close
        commands_pipe_read.close

        require_relative "tui/model"

        queue = Queue.new

        reader = Thread.new do
          events_pipe_read.each_line do |line|
            queue << JSON.parse(line, symbolize_names: false).transform_keys(&:to_sym)
          rescue JSON::ParserError
            nil
          end
        end

        print "\e[2J\e[H\e[?25l"

        model = Model.new(
          series: series,
          imported_series: imported_series,
          imported_events: imported_events,
          queue: queue,
          commands: commands_pipe_write
        )

        ::Bubbletea.run(model)

        commands_pipe_write.close unless commands_pipe_write.closed?

        if model.importing?
          begin
            Process.kill("TERM", -worker_pid)
          rescue Errno::ESRCH, Errno::EPERM
            nil
          end
        end

        Process.waitpid2(worker_pid)
        reader.join
        events_pipe_read.close unless events_pipe_read.closed?
      end
    end

    class Worker
      def initialize(commands, events)
        @commands = commands
        @events = events
        @mutex = Mutex.new
      end

      def loop
        @commands.each_line do |line|
          command = JSON.parse(line, symbolize_names: true)
          perform(command)
        rescue JSON::ParserError
          nil
        end

        exit!(0)
      end

      def emit(event)
        @mutex.synchronize { @events.puts(JSON.generate(event)) }
      end

      private

      def perform(command)
        if command[:kind] == "talks"
          perform_talks(command[:slug])
        else
          perform_import(command)
        end
      end

      def perform_talks(slug)
        talks = Static::Video.where_event_slug(slug).flat_map { |video| talk_payload(video) }

        emit(type: "talks", slug: slug, talks: talks)
      rescue => error
        emit(type: "talks", slug: slug, talks: [], error: "#{error.class}: #{error.message}")
      end

      def talk_payload(video, extra_depth = 0)
        node = {
          title: (video.try(:title).presence || video.try(:raw_title)).to_s,
          speakers: Array(video["speakers"]),
          talk_kind: video.try(:kind),
          date: video["date"],
          language: video.try(:language),
          provider: video["video_provider"],
          video_id: video["video_id"],
          slides_url: video["slides_url"],
          extra_depth: extra_depth
        }

        [node] + video.talks.flat_map { |talk| talk_payload(talk, extra_depth + 1) }
      end

      def perform_import(command)
        kind = command[:kind]
        slug = command[:slug]

        emit(type: "import_started", kind: kind, slug: slug)

        original, $stdout = $stdout, LineEmitter.new(self)

        begin
          case kind
          when "series"
            Static::EventSeries.find_by_slug(slug)&.import!
          when "event"
            Static::Event.all.to_a.find { |event| event.slug == slug }&.import!
          end

          $stdout.flush
          emit(type: "import_done", kind: kind, slug: slug)
        rescue => error
          $stdout.flush
          emit(type: "import_failed", kind: kind, slug: slug, error: "#{error.class}: #{error.message}")
        ensure
          $stdout = original
        end
      end
    end

    class LineEmitter
      def initialize(worker)
        @worker = worker
        @buffer = +""
      end

      def write(*args)
        @buffer << args.join

        while (index = @buffer.index("\n"))
          line = @buffer.slice!(0..index).chomp
          @worker.emit(type: "log", line: line)
        end

        args.sum(&:length)
      end

      def puts(*args)
        args = [""] if args.empty?
        args.each { |arg| write("#{arg}\n") }
        nil
      end

      def print(*args) = write(*args)

      def flush
        return if @buffer.empty?

        @worker.emit(type: "log", line: @buffer.dup)
        @buffer.clear
      end

      def sync = true

      def sync=(value)
        value
      end

      def tty? = false
      alias_method :isatty, :tty?

      def close = flush
      def closed? = false
    end
  end
end
