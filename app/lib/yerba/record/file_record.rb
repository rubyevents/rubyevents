# frozen_string_literal: true

module Yerba
  module Record
    # A record backed by a file instead of YAML, like an image. Its attributes are the segments of its path:
    #
    #   class Static::Sticker < Yerba::Record::FileRecord
    #     self.path = "app/assets/images/events/:series_id/:event_id/sticker*.webp"
    #
    #     belongs_to :event
    #   end
    class FileRecord
      include Querying
      include Associations

      attr_reader :file_path

      def self.all
        current_scope || (@all ||= Collection.new(record_class: self, records: records_matching(path_pattern.glob, root)))
      end

      def self.find_by(**criteria)
        all.find_by(**criteria)
      end

      # The records with the given path segments, like `Static::Sticker.matching({series_id: "rubyconf", event_id: "rubyconf-2024"})`
      def self.matching(params, root: self.root)
        glob = path_pattern.expand_glob(params)

        Collection.new(record_class: self, records: glob ? records_matching(glob, root) : [])
      end

      def self.records_matching(glob, root)
        Dir.glob(File.expand_path(glob, root.to_s)).sort.map { |file_path| new(file_path) }
      end
      private_class_method :records_matching

      def initialize(file_path)
        @file_path = File.expand_path(file_path.to_s)
      end

      def path
        Pathname.new(file_path)
      end

      def basename
        File.basename(file_path, ".*")
      end

      def path_params
        @path_params ||= self.class.path_params_for(file_path) || {}
      end

      def path_changes
        @path_changes ||= {}
      end

      def path_root
        self.class.path_pattern&.root_of(file_path) || self.class.root
      end

      # Moves the file to the path with the changed segments: `sticker.event_id = "rubyconf-2025"; sticker.save!`
      def save!
        to = path_params.merge(path_changes)
        return self if to == path_params

        target = self.class.path_pattern.rewrite(file_path, to)
        raise ArgumentError, "#{target} already exists" if File.exist?(target)

        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.mv(file_path, target)

        @file_path = target
        @path_params = nil
        @path_changes = nil
        self.class.unload!

        self
      end

      def move_to!(**changes)
        changes.each { |name, value| path_changes[name.to_sym] = value.to_s }

        save!
      end

      def key?(_key)
        false
      end

      def [](key)
        path_params[key.to_sym]
      end

      def ==(other)
        other.instance_of?(self.class) && other.file_path == file_path
      end
      alias_method :eql?, :==

      def hash
        [self.class, file_path].hash
      end

      def inspect
        "#<#{self.class.name} #{file_path}>"
      end
    end
  end
end
