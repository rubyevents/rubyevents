# frozen_string_literal: true

module Static
  class Speakers
    class << self
      attr_writer :path

      def path
        (@path || Rails.root.join(SpeakersFile::SPEAKERS_PATH)).to_s
      end

      def document
        @document ||= Yerba::Record::Document.new(path)
      end

      def all
        Yerba::Record::Collection.new(document: document, entry_class: Static::Speaker)
      end

      def find_by(name: nil, slug: nil, github: nil)
        index = speakers_file.index_by(:name)[name] if name
        index ||= speakers_file.index_by(:slug)[slug] if slug
        index ||= speakers_file.index_by(:github)[github] if github

        index ||= alias_index[name] if name

        return nil unless index

        Static::Speaker.new(document: document, index: index)
      end

      def find_or_create_by(name:)
        find_by(name: name) || create(name: name)
      end

      def create(name:, github: "", slug: nil, **attributes)
        slug ||= name.parameterize

        document.yerba << {name: name, github: github, slug: slug, **attributes}
        document.yerba.sort(by: :name)
        document.save!

        reset!

        find_by(name: name)
      end

      def reset!
        @document = nil
        @speakers_file = nil
        @alias_index = nil
      end

      private

      def speakers_file
        @speakers_file ||= Static::SpeakersFile.new(path)
      end

      def alias_index
        @alias_index ||= speakers_file.entries.each_with_index.with_object({}) do |(entry, index), result|
          next unless entry.is_a?(Hash)

          Array(entry["aliases"]).each do |alias_entry|
            result[alias_entry["name"]] ||= index if alias_entry.respond_to?(:key?) && alias_entry["name"]
          end
        end
      end
    end
  end
end
