# frozen_string_literal: true

module Generators
  module YerbaActions
    def yaml_file(path, object)
      document = Yerba::Document.from(object, path: path.to_s)
      yerbafile = Yerba::Yerbafile.find
      yerbafile&.apply(document)

      create_file path, document.to_s
    end

    def yaml_upsert(path, attributes, unique_by:, selector: nil)
      destination = "#{yaml_destination(path)} (#{unique_by.map { |key, value| "#{key}: #{value}" }.join(", ")})"

      unless File.exist?(path.to_s)
        if behavior == :invoke && !options[:pretend]
          raise Thor::Error, "#{path} does not exist. Create it (e.g. with `template` or `yaml_file`) before calling yaml_upsert."
        end

        return say_status((behavior == :invoke) ? :insert : :skip, destination)
      end

      document = Yerba.parse_file(path.to_s)
      target = selector ? document.fetch(selector) : document
      existing = target.find_by(**unique_by)

      if behavior == :invoke
        existing&.delete
        target << attributes

        say_status(existing ? :update : :insert, destination, existing ? :yellow : :green)
        document.save!(apply: true) unless options[:pretend]
      elsif existing
        existing.delete

        say_status(:remove, destination, :red)
        document.save!(apply: true) unless options[:pretend]
      else
        say_status(:skip, destination, :yellow)
      end
    end

    def yaml_insert(path, selector, value, before: nil, after: nil)
      destination = "#{yaml_destination(path)} #{selector}"

      if behavior == :invoke
        say_status(:insert, destination)
        return if options[:pretend]

        document = Yerba.parse_file(path.to_s)
        *parent_path, key = selector.split(".")
        parent = parent_path.empty? ? document.root : document.fetch(parent_path.join("."))
        parent.insert(key, value, before: before, after: after)
        document.save!(apply: true)
      else
        document = File.exist?(path.to_s) ? Yerba.parse_file(path.to_s) : nil

        if document&.exists?(selector)
          say_status(:remove, destination, :red)
          return if options[:pretend]

          document.delete(selector)
          document.save!(apply: true)
        else
          say_status(:skip, destination, :yellow)
        end
      end
    end

    def yaml_append(path, value, selector: nil, unique_by: nil)
      raw = value.is_a?(String) && value.include?("\n")

      if raw && unique_by.nil?
        raise ArgumentError, "yaml_append with raw YAML content needs unique_by: to be revocable"
      end

      destination = [yaml_destination(path), selector].compact.join(" ")
      destination += " (#{unique_by.map { |key, val| "#{key}: #{val}" }.join(", ")})" if unique_by

      if behavior == :invoke
        say_status(:append, destination)
        return if options[:pretend]

        document = Yerba.parse_file(path.to_s)

        if raw
          document.insert(selector.to_s, value.chomp)
        else
          target = selector ? document.fetch(selector) : document
          target << value
        end

        document.save!(apply: true)
      else
        document = File.exist?(path.to_s) ? Yerba.parse_file(path.to_s) : nil
        target = if document
          selector ? document.fetch(selector) : document.root
        end

        matcher = unique_by || (value.is_a?(Hash) ? value : nil)
        existing = matcher ? target&.find_by(**matcher) : target&.find_by(value)

        if existing
          say_status(:remove, destination, :red)
          return if options[:pretend]

          matcher ? existing.delete : target.remove(value)
          document.save!(apply: true)
        else
          say_status(:skip, destination, :yellow)
        end
      end
    end
    def yaml_rename(path, selector, new_name)
      *parent_path, old_name = selector.split(".")
      renamed_selector = [*parent_path, new_name].join(".")

      if behavior == :invoke
        say_status(:rename, "#{yaml_destination(path)} #{selector} -> #{new_name}")
        return if options[:pretend]

        document = Yerba.parse_file(path.to_s)
        document.rename(selector, renamed_selector)
        document.save!(apply: true)
      else
        document = File.exist?(path.to_s) ? Yerba.parse_file(path.to_s) : nil

        if document&.exists?(renamed_selector)
          say_status(:rename, "#{yaml_destination(path)} #{renamed_selector} -> #{old_name}", :red)
          return if options[:pretend]

          document.rename(renamed_selector, selector)
          document.save!(apply: true)
        else
          say_status(:skip, "#{yaml_destination(path)} #{renamed_selector}", :yellow)
        end
      end
    end

    def yaml_set(path, selector, value)
      yaml_edit(path, :yaml_set, selector) do |document|
        document[selector] = value
      end
    end

    def yaml_remove(path, selector, value = nil)
      yaml_edit(path, :yaml_remove, [selector, value].compact.join(" "), color: :red) do |document|
        value ? document.remove(selector, value.to_s) : document.delete(selector)
      end
    end

    def yaml_sort(path, selector = "", by: nil, case_sensitive: false)
      yaml_edit(path, :sort, [selector.presence, by && "by #{by}"].compact.join(" ")) do |document|
        document.sort(selector, by: by, case_sensitive: case_sensitive)
      end
    end

    def yaml_sort_keys(path, order, selector: "")
      yaml_edit(path, :sort_keys, selector.presence) do |document|
        document.sort_keys(selector, order)
      end
    end

    def yaml_apply(path)
      yaml_edit(path, :yaml_apply)
    end

    private

    def yaml_edit(path, status, detail = nil, color: :green)
      return unless behavior == :invoke

      say_status(status, [yaml_destination(path), detail.presence].compact.join(" "), color)
      return if options[:pretend]

      document = Yerba.parse_file(path.to_s)
      yield document if block_given?
      document.save!(apply: true)
    end

    def yaml_destination(path)
      relative_to_original_destination_root(path.to_s)
    end
  end
end
