# frozen_string_literal: true

require "json"
require "stringio"

module Validate
  module TUI
    class << self
      def run(sections)
        read_pipe, write_pipe = IO.pipe

        child_pid = fork do
          Process.setpgid(0, 0)
          Signal.trap("TERM") { exit!(1) }
          read_pipe.close
          run_sections(sections, write_pipe)
        end

        begin
          Process.setpgid(child_pid, child_pid)
        rescue Errno::EACCES, Errno::ESRCH, Errno::EPERM
          nil
        end

        write_pipe.close

        require_relative "tui/model"

        queue = Queue.new

        reader = Thread.new do
          read_pipe.each_line do |line|
            queue << JSON.parse(line, symbolize_names: false).transform_keys(&:to_sym)
          rescue JSON::ParserError
            nil
          end
        end

        print "\e[2J\e[H\e[?25l"

        model = Model.new(sections.keys, queue)
        ::Bubbletea.run(model)

        if model.aborted?
          begin
            Process.kill("TERM", -child_pid)
          rescue Errno::ESRCH, Errno::EPERM
            nil
          end
        end

        _, status = Process.waitpid2(child_pid)
        reader.join
        read_pipe.close unless read_pipe.closed?

        [status.success? && !model.aborted?, model.failures]
      end

      private

      def run_sections(sections, pipe)
        ENV["CLICOLOR_FORCE"] = "1"

        emit_mutex = Mutex.new
        emit = ->(event) { emit_mutex.synchronize { pipe.puts(JSON.generate(event)) } }
        on_start = ->(title, _index) { emit.call(type: "section_start", title: title) }

        on_finish = ->(title, _index, result) {
          emit.call(type: "section_result", title: title, passed: result[0], output: result[1])
        }

        results = Parallel.map(sections.keys, in_processes: sections.size, start: on_start, finish: on_finish) do |title|
          captured = StringIO.new
          original, $stdout = $stdout, captured

          begin
            [sections.fetch(title).call, captured.string]
          ensure
            $stdout = original
          end
        end

        passed = results.all? { |section_passed, _output| section_passed }
        emit.call(type: "done", passed: passed)
        pipe.close

        exit!(passed ? 0 : 1)
      end
    end
  end
end
