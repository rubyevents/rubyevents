# == Schema Information
#
# Table name: topic_gems
# Database name: primary
#
#  id         :integer          not null, primary key
#  gem_name   :string           not null, uniquely indexed => [topic_id]
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  topic_id   :integer          not null, indexed, uniquely indexed => [gem_name]
#
# Indexes
#
#  index_topic_gems_on_topic_id               (topic_id)
#  index_topic_gems_on_topic_id_and_gem_name  (topic_id,gem_name) UNIQUE
#
# Foreign Keys
#
#  topic_id  (topic_id => topics.id)
#
class TopicGem < ApplicationRecord
  belongs_to :topic

  validates :gem_name, presence: true, uniqueness: {scope: :topic_id}

  def info
    @info ||= Rails.cache.fetch(cache_key, expires_in: 7.days) do
      fetch_gem_info
    end
  end

  def downloads
    info&.dig("downloads")
  end

  def version
    info&.dig("version")
  end

  def version_created_at
    date = info&.dig("version_created_at")
    Time.parse(date) if date.present?
  rescue
    nil
  end

  def authors
    info&.dig("authors")
  end

  def author_names
    return [] unless authors.present?

    authors.split(/,\s*/)
  end

  def author_users
    return {} unless author_names.any?

    User.where(name: author_names).index_by(&:name)
  end

  def owners
    @owners ||= Rails.cache.fetch(owners_cache_key, expires_in: 7.days) do
      fetch_owners
    end
  end

  def owner_handles
    owners&.map { |o| o["handle"] }&.compact || []
  end

  def owner_users
    return [] unless owner_handles.any?

    User.canonical.where(github_handle: owner_handles).order(talks_count: :desc)
  end

  def maintainers
    # Combine owners (by github handle) and authors (by name), deduplicated
    (owner_users.to_a + author_users.values).uniq.sort_by { |u| -u.talks_count }
  end

  def summary
    info&.dig("info")
  end

  def licenses
    info&.dig("licenses") || []
  end

  def license
    licenses.first
  end

  def homepage_url
    info&.dig("homepage_uri")
  end

  def source_code_url
    info&.dig("source_code_uri")
  end

  def documentation_url
    info&.dig("documentation_uri")
  end

  def changelog_url
    info&.dig("changelog_uri")
  end

  def bug_tracker_url
    info&.dig("bug_tracker_uri")
  end

  def mailing_list_url
    info&.dig("mailing_list_uri")
  end

  def wiki_url
    info&.dig("wiki_uri")
  end

  def funding_url
    info&.dig("funding_uri")
  end

  def runtime_dependencies
    info&.dig("dependencies", "runtime") || []
  end

  def development_dependencies
    info&.dig("dependencies", "development") || []
  end

  def rubygems_url
    "https://rubygems.org/gems/#{gem_name}"
  end

  def github_repo
    url = source_code_url.presence || homepage_url
    return nil unless url.present?

    match = url.match(%r{github\.com/([^/]+/[^/]+)})
    match[1].sub(/\.git$/, "").split("/tree/").first if match
  end

  def github_url
    return nil unless github_repo.present?

    "https://github.com/#{github_repo}"
  end

  private

  def fetch_gem_info
    Gems.info(gem_name)
  rescue => e
    Rails.logger.error("Failed to fetch gem info for #{gem_name}: #{e.message}")
    nil
  end

  def fetch_owners
    Gems.owners(gem_name)
  rescue => e
    Rails.logger.error("Failed to fetch owners for #{gem_name}: #{e.message}")
    []
  end

  def cache_key
    "topic_gem_info:#{id}:#{gem_name}"
  end

  def owners_cache_key
    "topic_gem_owners:#{id}:#{gem_name}"
  end
end
