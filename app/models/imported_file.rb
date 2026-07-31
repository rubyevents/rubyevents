# frozen_string_literal: true

# == Schema Information
#
# Table name: imported_files
# Database name: primary
#
#  id          :integer          not null, primary key
#  file_path   :string           not null, uniquely indexed
#  fingerprint :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_imported_files_on_file_path  (file_path) UNIQUE
#
require "digest"

class ImportedFile < ApplicationRecord
  def self.digest(path)
    absolute = absolute_path(path)
    return nil unless File.exist?(absolute)

    Digest::MD5.file(absolute).hexdigest
  end

  def self.changed?(path)
    stored = find_by(file_path: relative_path(path))&.fingerprint

    stored != digest(path)
  end

  def self.record!(path)
    fingerprint = digest(path)

    return if fingerprint.nil?

    upsert(
      {file_path: relative_path(path), fingerprint: fingerprint, created_at: Time.current, updated_at: Time.current},
      unique_by: :file_path
    )
  end

  def self.forget!(path)
    where(file_path: relative_path(path)).delete_all
  end

  def self.prune_missing!
    find_each do |imported_file|
      imported_file.destroy unless File.exist?(absolute_path(imported_file.file_path))
    end
  end

  def self.relative_path(path)
    pathname = Pathname.new(path.to_s)
    pathname = pathname.relative_path_from(Rails.root) if pathname.absolute?

    pathname.to_s
  end

  def self.absolute_path(path)
    pathname = Pathname.new(path.to_s)

    pathname.absolute? ? pathname.to_s : Rails.root.join(pathname).to_s
  end
end
