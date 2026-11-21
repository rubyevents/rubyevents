# frozen_string_literal: true

module Static
  # Talk ids are "firstname-lastname-event", with the kind added on duplicates, the kind alone for
  # talks without one or two speakers, and the title in slug form as a last resort. The expected ids
  # depend on the other talks of the file, so they're worked out for the whole file at once.
  #
  class TalkIdValidator < ActiveModel::Validator
    include GitBaseline

    def validate(talk)
      expected = expected_id(talk)
      return unless expected

      talk.errors.add(:id, %("#{talk["id"]}" does not match the expected id "#{expected}". Run `bin/rails validate:fix` to rename it and keep the current id as old_id.))
    end

    def fix(talk)
      expected = expected_id(talk)
      return 0 unless expected

      current = talk["id"].to_s
      watchable = talk["video_provider"].in?(::Talk::WATCHABLE_PROVIDERS)

      # Production is seeded from the baseline, so a committed id is the one it knows the talk by
      talk["old_id"] = current if baseline_ids(talk).include?(current) || self.class.baseline_talk_ids.include?(current)
      talk.delete("old_id") if talk["old_id"] == expected
      talk["video_id"] = expected if talk["video_id"] == current && !watchable
      talk["id"] = expected

      move_cued_thumbnail(talk, current, expected) if watchable && talk["start_cue"].present?

      1
    end

    private

    def expected_id(talk)
      expected = expected_ids(talk)[[talk.selector, talk["id"].to_s]]

      expected unless expected.nil? || expected == talk["id"].to_s
    end

    # [selector, id] => expected id, for every talk of the file
    def expected_ids(talk)
      Yerba::Record::Validations.cached(self.class, talk.file_path, :expected_ids) do
        FileIds.new(talk.file_records.to_a, event_slug(talk)).expected.transform_keys { |node| [node.selector, node["id"].to_s] }
      end
    end

    def baseline_ids(talk)
      Yerba::Record::Validations.cached(self.class, talk.file_path, :baseline_ids) do
        document = self.class.baseline_file(talk.project_file_path)
        document ? Static::Talk.in_file(talk.project_file_path, document: document).ids : []
      end
    end

    def move_cued_thumbnail(talk, current, expected)
      directory = File.join(talk.path_root.to_s, "app/assets/images/thumbnails", event_slug(talk))
      source = File.join(directory, "#{current}.webp")
      target = File.join(directory, "#{expected}.webp")

      FileUtils.mv(source, target) if File.exist?(source) && !File.exist?(target)
    end

    def event_slug(talk)
      File.basename(File.dirname(File.expand_path(talk.file_path.to_s)))
    end

    class FileIds
      def initialize(nodes, event_slug)
        @nodes = nodes
        @event_slug = event_slug
      end

      def expected
        @nodes.group_by { |node| speaker_id(node) }.each_with_object({}) do |(id, group), result|
          next if id.blank?
          next result[group.first] = id if group.one? && available?(group.first, id)

          group.group_by { |node| kind_id(node) }.each do |with_kind, kind_group|
            next if with_kind.blank?
            next result[kind_group.first] = with_kind if kind_group.one? && available?(kind_group.first, with_kind)

            kind_group.group_by { |node| title_id(node) }.each do |with_title, title_group|
              next if with_title.blank?

              if title_group.one? && available?(title_group.first, with_title)
                result[title_group.first] = with_title
              else
                title_group.each_with_index { |node, index| result[node] = numbered(node, with_title, index + 1) }
              end
            end
          end
        end
      end

      private

      def id_for(node)
        @ids ||= {}
        @ids[node] ||= ::Talk::StaticID.new(event_slug: @event_slug, title: node["title"], speakers: node["speakers"], kind: node["kind"])
      end

      def speaker_id(node) = id_for(node).speaker_id

      def kind_id(node) = id_for(node).kind_id

      def title_id(node) = id_for(node).title_id

      def numbered(node, id, index)
        index += 1 until available?(node, candidate = id.sub(/-#{Regexp.escape(@event_slug)}\z/, "-#{index}-#{@event_slug}"))

        candidate
      end

      def available?(node, candidate)
        (reservations.fetch(candidate, []) - [node]).empty?
      end

      def reservations
        @reservations ||= @nodes.each_with_object({}) do |node, result|
          [node["id"], node["old_id"]].each do |value|
            (result[value] ||= []) << node if value.present?
          end
        end
      end
    end
  end
end
