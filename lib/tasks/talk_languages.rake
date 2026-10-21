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

    Dir.glob(Static::Talk.file_glob).sort.each do |path|
      talks = Static::Talk.in_file(path)
      next unless talks.any? { |talk| !talk.valid?(:lint) && talk.errors.any? { |error| error.message.include?(%(explicit "language")) } }

      relative_path = path.to_s.sub("#{Rails.root}/", "")

      detections = talks.filter_map do |talk|
        next if talk["talks"] || talk["language"].present?

        source = (talk["video_provider"] == "parent") ? talk.parent : talk
        provider = source&.[]("video_provider")

        next unless provider.in?(::Talk::WATCHABLE_PROVIDERS)

        unless provider == "youtube"
          unresolved << "#{relative_path}: #{talk.id} (no captions to detect from on #{provider})"
          next
        end

        [talk, detect.call(source["video_id"])]
      end

      resolved, undetectable = detections.partition { |_talk, language| language.present? }

      undetectable.each do |talk, _language|
        unresolved << "#{relative_path}: #{talk.id} (no captions or ambiguous language)"
      end

      resolved.each do |talk, language|
        talk["language"] = language
        written += 1
        puts %(#{relative_path}: #{talk.id} language: "#{language}")
      end

      talks.save! if resolved.any?
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
