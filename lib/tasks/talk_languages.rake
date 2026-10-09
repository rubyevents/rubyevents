# frozen_string_literal: true

namespace :talk_languages do
  desc "Backfill missing language keys from the language of each talk's YouTube captions"
  task backfill: :environment do
    cache_path = Rails.root.join("tmp/talk_language_detections.json")
    detected = cache_path.exist? ? JSON.parse(cache_path.read) : {}

    detect = lambda do |video_id|
      detected.fetch(video_id) do
        transcripts = YouTube::Transcript.list(video_id)&.to_a || []
        candidates = transcripts.select(&:is_generated).presence || transcripts
        codes = candidates.map { |transcript| transcript.language_code.to_s.split("-").first }.uniq

        detected[video_id] = codes.one? ? Language.by_code(codes.first) : nil
        cache_path.write(JSON.generate(detected))

        puts "Checked #{detected.size} video(s)..." if (detected.size % 100).zero?

        detected[video_id]
      end
    end

    written = 0
    unresolved = []

    Dir.glob(Rails.root.join("data/**/videos.yml")).sort.each do |path|
      validator = Static::Validators::TalkLanguage.new(file_path: path)
      next unless validator.applicable? && validator.errors.any?

      relative_path = path.to_s.sub("#{Rails.root}/", "")
      document = Yerba.parse_file(path)
      next unless document.root

      pairs = document.root.each.flat_map do |video|
        [[video, nil]] + Array(video["talks"]&.each&.to_a).map { |talk| [talk, video] }
      end

      detections = pairs.filter_map do |node, parent|
        next if node["talks"] || node.value_at("language").present?

        source = (node.value_at("video_provider") == "parent") ? parent : node
        provider = source&.value_at("video_provider")

        next unless provider.in?(::Talk::WATCHABLE_PROVIDERS)

        unless provider == "youtube"
          unresolved << "#{relative_path}: #{node.value_at("id")} (no captions to detect from on #{provider})"
          next
        end

        [node, detect.call(source.value_at("video_id"))]
      end

      resolved, undetectable = detections.partition { |_node, language| language.present? }

      undetectable.each do |node, _language|
        unresolved << "#{relative_path}: #{node.value_at("id")} (no captions or ambiguous language)"
      end

      resolved.each do |node, language|
        node["language"] = language
        written += 1
        puts %(#{relative_path}: #{node.value_at("id")} language: "#{language}")
      end

      document.save!(apply: true) if resolved.any?
    end

    puts
    puts "Wrote #{written} language(s)"

    if unresolved.any?
      puts
      puts "Could not detect a language for #{unresolved.size} talk(s):"
      unresolved.each { |line| puts "  #{line}" }
    end
  end
end
