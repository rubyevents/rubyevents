# frozen_string_literal: true

module Yerba
  module Record
    module Querying
      extend ActiveSupport::Concern

      class_methods do
        attr_reader :path, :scalar_field, :nested_key, :order_by
        attr_writer :glob, :base_path, :flatten, :scalar_field, :order_by, :root

        delegate :count, :first, :last, :empty?, :each, :pluck, to: :all

        def path=(value)
          @path = value&.to_s
          @path_pattern = nil

          define_path_segment_accessors
        end

        def path_pattern
          @path_pattern ||= PathPattern.new(path) if path
        end

        def root
          @root || superclass.try(:root) || Dir.pwd
        end

        def base_path
          @base_path || (File.expand_path(path_pattern.prefix, root) if path) || superclass.try(:base_path)
        end

        def glob
          @glob || (path_pattern.glob.delete_prefix("#{path_pattern.prefix}/") if path_pattern&.dynamic?)
        end

        def path_params_for(file_path)
          return nil unless file_path && path_pattern&.dynamic?

          path_pattern.match(File.expand_path(file_path.to_s))
        end

        def path_for(params, root: self.root)
          relative_path = path_pattern&.expand(params)

          File.expand_path(relative_path, root.to_s) if relative_path
        end

        def find_by_file_path(file_path)
          return nil unless file_path

          all.cached(:records_by_file_path) { all.index_by { |record| record.file_path.to_s } }[File.expand_path(file_path.to_s)]
        end

        def flatten
          @flatten || false
        end

        def all
          current_scope || nested_all || (@all ||= Collection.new(record_class: self, sources: default_sources))
        end

        def nested_all
          owner_name, association = Associations.nested_owners[name]
          return unless owner_name

          records = owner_name.constantize.all.select { |record| record.key?(association) }.flat_map { |record| record.public_send(association).to_a }

          Collection.new(record_class: self, records: records)
        end

        def where(...)
          all.where(...)
        end

        def in_file(path, document: nil)
          Collection.new(record_class: self, sources: [Collection::Source.new(path: path, document: document, mode: source_mode)])
        end

        def parse(content, path: nil)
          in_file(path, document: Yerba.parse(content.to_s))
        end

        def with_path(path)
          previous = @path
          self.path = path

          unload!

          yield
        ensure
          self.path = previous
          unload!
        end

        # Like ActiveRecord scopes: `scope :top_level, -> { where.missing(:parent) }`
        def scope(name, body)
          define_singleton_method(name) { |*args| all.instance_exec(*args, &body) }
        end

        # Makes `all` return `collection` inside the block. Collections call the model's class methods this way,
        # so `static_event.talks.pairs` runs `Static::Talk.pairs` over that one file.
        def scoping(collection)
          scopes = (Thread.current[:yerba_record_scopes] ||= {})
          previous = scopes[self]
          scopes[self] = collection

          begin
            yield
          ensure
            scopes[self] = previous
          end
        end

        def current_scope
          Thread.current[:yerba_record_scopes]&.[](self)
        end

        def file_path
          return nil unless path && !path_pattern.dynamic?

          File.expand_path(path, root)
        end

        def file_glob
          return nil unless glob

          base_path ? File.join(base_path, glob) : glob
        end

        def unload!
          @all = nil
          @indexes = nil
        end

        def reset_loaded!(except: nil)
          if @all && except && @all.equal?(except)
            @all.reset!
          else
            unload!
          end
        end

        def source_mode
          if glob
            flatten ? :items : :single
          else
            scalar_field ? :scalar : :items
          end
        end

        private

        def define_path_segment_accessors
          (path_pattern&.names.to_a - [:id]).each do |name|
            define_method(name) { path_changes.fetch(name) { path_params[name] } } unless method_defined?(name)
            define_method(:"#{name}=") { |value| path_changes[name] = value.to_s } unless method_defined?(:"#{name}=")
          end
        end

        def default_sources
          if glob
            Dir.glob(file_glob).sort.map { |file| Collection::Source.new(path: file, mode: source_mode) }
          elsif path
            [Collection::Source.new(path: file_path, mode: source_mode)]
          else
            raise "Set self.path or self.glob on #{name}"
          end
        end
      end
    end
  end
end
