class SitemapsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    render xml: generate_sitemap_string, content_type: "application/xml"
  end

  private

  def generate_sitemap_string
    Rails.cache.fetch(["sitemap", Talk.all, Event.all, User.speakers, Topic.approved], expires_in: 24.hours) do
      adapter = SitemapStringAdapter.new

      SitemapGenerator::Sitemap.default_host = "https://www.rubyevents.org"

      SitemapGenerator::Sitemap.create(adapter: adapter) do
        add talks_path, priority: 0.9, changefreq: "weekly"

        Talk.pluck(:slug, :updated_at).each do |talk_slug, updated_at|
          add talk_path(talk_slug), priority: 0.9, lastmod: updated_at
        end

        add speakers_path, priority: 0.7, changefreq: "weekly"

        User.speakers.canonical.pluck(:slug, :updated_at).each do |speaker_slug, updated_at|
          add profile_path(speaker_slug), priority: 0.9, lastmod: updated_at
        end

        add events_path, priority: 0.7, changefreq: "weekly"

        Event.canonical.pluck(:slug, :updated_at) do |event_slug, updated_at|
          add event_path(event_slug), priority: 0.9, lastmod: updated_at
        end

        add topics_path, priority: 0.7, changefreq: "weekly"

        Topic.approved.pluck(:slug, :updated_at).each do |topic_slug, updated_at|
          add topic_path(topic_slug), priority: 0.9, lastmod: updated_at
        end
      end
      adapter.sitemap_content
    end
  end

  class SitemapStringAdapter
    attr_reader :sitemap_content

    def write(location, raw_data)
      @sitemap_content ||= ""
      @sitemap_content << raw_data
    end
  end
end
