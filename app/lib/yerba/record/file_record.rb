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
    #
    class FileRecord
      include Querying
      include Associations
      include Validations

      attr_reader :file_path

      def self.types(*class_names)
        @types = class_names if class_names.any?

        @types || []
      end

      def self.constraints=(constraints)
        @constraints = constraints
      end

      def self.constraints
        @constraints || {}
      end

      def self.order_by
        @order_by || (superclass.order_by if superclass <= FileRecord)
      end

      def self.all
        current_scope || (@all ||= Collection.new(record_class: self, records: records_matching(record_classes.to_h { |klass| [klass, klass.path_pattern.glob] }, root)))
      end

      def self.find_by(**criteria)
        all.find_by(**criteria)
      end

      def self.matching(params, root: self.root)
        globs = record_classes.to_h { |klass| [klass, klass.path_pattern.expand_glob(params)] }.compact

        Collection.new(record_class: self, records: records_matching(globs, root))
      end

      def self.type_for(file_path)
        candidates = type_root ? type_root.types.map(&:constantize) : [self]

        candidates.find { |klass| klass.matches?(file_path) }
      end

      def self.matches?(file_path)
        return false unless path

        params = path_params_for(file_path)

        params.present? && constraints.all? { |name, constraint| params[name].to_s.match?(/\A(?:#{constraint.source})\z/) }
      end

      def self.unload!
        return super unless type_root

        [type_root, *type_root.types.map(&:constantize)].uniq.each { |klass| klass.instance_variable_set(:@all, nil) }
      end

      def self.type_root
        ancestors.find { |ancestor| ancestor.is_a?(Class) && ancestor <= FileRecord && ancestor.instance_variable_get(:@types).present? }
      end

      def self.record_classes
        classes = type_root ? type_root.types.map(&:constantize).select { |klass| klass <= self } : []
        classes = [self, *classes] if path && !classes.include?(self)

        classes.select(&:path)
      end

      def self.records_matching(globs, root)
        files = globs.values.flat_map { |glob| Dir.glob(File.expand_path(glob, root.to_s)) }.uniq.sort

        records = files.filter_map do |file_path|
          klass = type_for(file_path)

          klass.new(file_path) if klass && klass <= self
        end

        order_by ? records.sort_by { |record| record.public_send(order_by).to_s } : records
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

      def save!(validate: true, context: nil)
        validate_for_save!(context) if validate

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
