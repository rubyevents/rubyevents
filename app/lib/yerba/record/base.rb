# frozen_string_literal: true

module Yerba
  module Record
    class Base
      include Querying
      include Indexing
      include References
      include Associations
      include Schema
      include History

      attr_reader :document, :parent
      attr_reader :parsed_selector

      def self.to_selector(selector)
        return selector if selector.is_a?(Yerba::Selector)
        return nil if selector.blank?

        Yerba::Selector.parse(selector.to_s)
      end

      def initialize(attributes = nil, document: nil, index: nil, selector: nil, file_path: nil, parent: nil, **kwargs)
        if document
          @document = document
          @parsed_selector = Base.to_selector(selector) || (index && Yerba::Selector.build([index]))
          @file_path = file_path
          @parent = parent
          @new_record = false
        elsif attributes.is_a?(Hash) || kwargs.any?
          attrs = (attributes || {}).merge(kwargs).transform_keys(&:to_s)
          @document = Yerba::Document.from(attrs)
          @new_record = true
        else
          @document = document
          @new_record = false
        end
      end

      def new_record?
        @new_record
      end

      def persisted?
        !new_record? && !destroyed?
      end

      def destroyed?
        @destroyed == true
      end

      def [](key)
        attributes_cache[key.to_s]
      end

      def []=(key, value)
        raise_if_destroyed!
        remember_original(key)
        reset_attributes_cache!

        if scalar_node?
          document.root[index] = value if key.to_s == self.class.scalar_field
        else
          node[key.to_s] = value
        end
      end

      def key?(key)
        attributes_cache.key?(key.to_s)
      end

      def set(key, value, before: nil, after: nil, quote_style: nil)
        if key?(key)
          self[key] = value
        else
          insert(key, value, before: before, after: after)
        end

        node[key.to_s].quote_style = quote_style.to_s if quote_style

        value
      end

      def insert(key, value, before: nil, after: nil)
        raise_if_destroyed!
        remember_original(key)
        reset_attributes_cache!

        node.insert(key.to_s, value, before: before&.to_s, after: after&.to_s)
      end

      def delete(key)
        raise_if_destroyed!
        return unless key?(key)

        remember_original(key)
        reset_attributes_cache!

        node.delete(key.to_s)
      end

      def source_location(key = nil)
        target = if key
          node[key.to_s] if node.respond_to?(:[])
        else
          node
        end

        target.respond_to?(:location) ? target.location : nil
      end

      def source_line(key = nil)
        source_location(key)&.start_line
      end

      def selector
        @selector ||= parsed_selector&.to_s
      end

      def index
        segment = parsed_selector&.segments&.last

        segment if segment.is_a?(Integer)
      end

      def nested?
        !parent.nil?
      end

      def save!
        raise_if_destroyed!

        if new_record?
          path = persist_path

          raise "Cannot save: no persist_path defined" unless path
          raise ArgumentError, "#{self.class.name} already exists at #{path}" if File.exist?(path)

          directory = File.dirname(path)
          FileUtils.mkdir_p(directory) unless File.directory?(directory)

          validate! if self.class.schema

          document.save_to!(path)

          @new_record = false
          @was_new_record = true
        else
          to = path_params.merge(path_changes)
          to[:id] = self["id"].to_s if path_params.key?(:id) && self["id"].present?

          if to != path_params
            raise ArgumentError, "#{self.class.name} has no directory named by :id in its path" unless owns_id_directory?

            moves = planned_moves(to)
          end

          file_moves = planned_file_moves(to)

          document.save!(apply: true)
          move!(moves, to) if moves&.any?
          Base.move_files!(file_moves, moved: moves.to_a)
        end

        @path_changes = nil
        @original_attributes = nil

        reset_attributes_cache!

        self.class.reset_loaded!
      end

      def destroy
        raise_if_destroyed!
        raise "Cannot destroy a record without an index" if index.nil?

        attributes = attributes_cache.deep_dup.freeze

        document.remove_at(parsed_selector.parent.to_s, index)
        document.save!(apply: true)

        reset_attributes_cache!
        @attributes_cache = attributes
        @destroyed = true

        self.class.reset_loaded!
      end

      def update(**attributes)
        attributes.each { |key, value| self[key] = value }

        save!

        self
      end

      def changed?
        document.changed?
      end

      def validate!
        return unless self.class.schema

        errors = Yerba::Document.from(to_h).validate(self.class.schema.json_schema)

        if errors.any?
          error_messages = errors.map { |error| "#{error["message"]} at #{error["path"]}" }
          raise ArgumentError, "Validation failed: #{error_messages.join(", ")}"
        end
      end

      def id
        self["id"]
      end

      def file_path
        @file_path || document&.path
      end

      def relative_file_path
        return nil unless file_path && self.class.base_path

        @relative_file_path ||= Pathname.new(file_path).relative_path_from(self.class.base_path).to_s
      end

      def project_file_path
        return nil unless file_path

        Pathname.new(file_path).relative_path_from(Pathname.new(self.class.root.to_s)).to_s
      end

      def path_params
        @path_params ||= self.class.path_params_for(file_path) || {}
      end

      def path_root
        (file_path && self.class.path_pattern&.root_of(File.expand_path(file_path.to_s))) || self.class.root
      end

      def rename!(id)
        self["id"] = id
        save!

        self
      end

      def move_to!(**changes)
        changes.each do |name, value|
          if name.to_sym == :id
            self["id"] = value
          else
            path_changes[name.to_sym] = value.to_s
          end
        end

        save!

        self
      end

      def path_changes
        @path_changes ||= {}
      end

      def attribute_was(key)
        original_attributes.fetch(key.to_s) { self[key] }
      end

      def self.move_files!(moves, moved: [])
        moved = moved.map { |source, target| [source, target] }

        moves.each do |source, target, _directory|
          source, target = [source, target].map do |path|
            moved.reduce(path) { |current, (from, to)| current.start_with?("#{from}/") ? "#{to}#{current.delete_prefix(from)}" : current }
          end

          next if source == target || !File.exist?(source)

          FileUtils.mkdir_p(File.dirname(target))
          FileUtils.mv(source, target)

          moved << [source, target]
        end
      end

      def attributes
        to_h
      end

      def to_h
        attributes_cache.dup
      end

      def reset_attributes_cache!
        @attributes_cache = nil unless destroyed?
        @relative_file_path = nil
        @path_params = nil
        @nested_collections = nil

        parent&.reset_attributes_cache!
      end

      def ==(other)
        return super if new_record? || !other.is_a?(Base)

        other.class == self.class && other.document.equal?(document) && other.parsed_selector == parsed_selector
      end
      alias_method :eql?, :==

      def hash
        new_record? ? super : [self.class, document.object_id, parsed_selector].hash
      end

      def to_yaml
        node.respond_to?(:source) ? node.source : Yerba::Document.from(to_h).to_s
      end

      def inspect
        "#<#{self.class.name} #{to_h.inspect}>"
      end

      def persist_path
        nil
      end

      def node
        parsed_selector ? document[selector] : document.root
      end

      def scalar_node?
        self.class.scalar_field && node.is_a?(Yerba::Scalar)
      end

      private

      def missing_parent_message(directory, _to)
        "#{Pathname.new(directory).relative_path_from(Pathname.new(path_root.to_s))} doesn't exist yet, create it before moving the #{self.class.name.demodulize.underscore.humanize(capitalize: false)} there"
      end

      def planned_file_moves(to = path_params)
        return [] if self.class.file_associations.empty? || (original_attributes.empty? && to == path_params)

        root = path_root.to_s

        moves = self.class.file_associations.values.flat_map do |association|
          pattern = association[:pattern]
          from_values = segment_values(pattern, path_params) { |key| attribute_was(key) }
          to_values = segment_values(pattern, to) { |key| self[key] }
          next [] if from_values == to_values

          sources = if association[:glob]
            pattern.expand_glob(from_values)&.then { |glob| Dir.glob(File.expand_path(glob, root)).sort }.to_a
          else
            [resolve_file_association(pattern, from_values, root)]
          end

          sources.filter_map { |source| planned_file_move(pattern, association, source, to_values, root) }
        end

        moves.sort_by { |_source, _target, directory| directory ? 0 : 1 }
      end

      def planned_file_move(pattern, association, source, to_values, root)
        return nil unless source && File.exist?(source)

        target = if pattern.wildcard?
          pattern.rewrite(source, to_values)
        else
          pattern.expand(to_values)&.then { |path| File.expand_path(path, root) }
        end
        return nil if target.nil? || target == source || File.exist?(target)

        [source, target, association[:directory]]
      end

      def owns_id_directory?
        path_params.any? && self.class.path_pattern.expand_through(:id, path_params).present?
      end

      def planned_moves(to)
        from = path_params
        root = path_root.to_s
        directory = File.expand_path(self.class.path_pattern.expand_through(:id, to), root)
        raise ArgumentError, missing_parent_message(File.dirname(directory), to) unless File.directory?(File.dirname(directory))

        patterns = [[self.class.path_pattern.expand_through(:id, from), self.class.path_pattern.expand_through(:id, to)]]

        moves = patterns
          .filter_map { |source, target| [File.expand_path(source, root), File.expand_path(target, root)] if source && target }
          .select { |source, target| source != target && File.exist?(source) }

        moves.each { |_source, target| raise ArgumentError, "#{target} already exists" if File.exist?(target) }

        moves
      end

      def move!(moves, to)
        root = path_root.to_s

        moves.each do |source, target|
          FileUtils.mkdir_p(File.dirname(target))
          FileUtils.mv(source, target)
        end

        @document = Yerba.parse_file(self.class.path_for(to, root: root).to_s)
        @file_path = nil
        @path_params = nil

        Base.descendants.each(&:unload!)
      end

      def original_attributes
        @original_attributes ||= {}
      end

      def remember_original(key)
        original_attributes[key.to_s] = self[key] unless original_attributes.key?(key.to_s)
      end

      def segment_values(pattern, path_values)
        pattern.names.to_h { |name| [name, path_values.key?(name) ? path_values[name] : yield(name.to_s)&.to_s] }
      end

      def file_association_path(name)
        pattern = self.class.file_associations.fetch(name.to_sym)[:pattern]

        resolve_file_association(pattern, segment_values(pattern, path_params) { |key| self[key] }, path_root.to_s)
      end

      def resolve_file_association(pattern, values, root)
        if pattern.wildcard?
          glob = pattern.expand_glob(values)
          return nil unless glob

          existing = Dir.glob(File.expand_path(glob, root)).min
          fallback = glob.gsub("**/", "")

          existing || (File.expand_path(fallback, root) unless fallback.include?("*"))
        else
          pattern.expand(values)&.then { |path| File.expand_path(path, root) }
        end
      end

      def raise_if_destroyed!
        raise FrozenError.new("can't modify a destroyed #{self.class.name}", receiver: self) if destroyed?
      end

      def attributes_cache
        @attributes_cache ||= if scalar_node?
          {self.class.scalar_field => unwrap(node)}
        else
          values = parsed_selector ? parsed_selector.dig(document&.values) : document&.values
          values.is_a?(Hash) ? values : {}
        end
      end

      def unwrap(value)
        case value
        when Yerba::Scalar
          value.value
        when Yerba::Sequence
          value.map { |item| unwrap(item) }
        when Yerba::Map
          value.to_h
        else
          value
        end
      end

      def method_missing(name, *args)
        field = name.to_s

        if field.end_with?("=")
          self[field.chomp("=")] = args.first
        elsif field.end_with?("?")
          self[field.chomp("?")].present?
        elsif attributes_cache.key?(field)
          self[field]
        elsif @attributes&.key?(field)
          self[field]
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        field = name.to_s.chomp("=").chomp("?")

        return true if name.to_s.end_with?("=")
        return true if attributes_cache.key?(field)
        return true if @attributes&.key?(field)

        false
      end
    end
  end
end
