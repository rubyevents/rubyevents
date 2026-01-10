class Insights::ChartsController < ApplicationController
  skip_before_action :authenticate_user!

  def conference_season
    render partial: "insights/charts/radial_bar", locals: {
      frame_id: "chart_conference_season",
      url: monthly_distribution_insights_calendar_index_path(format: :json)
    }
  end

  def conference_calendar
    render partial: "insights/charts/heatmap", locals: {
      frame_id: "chart_conference_calendar",
      url: heatmap_insights_calendar_index_path(format: :json)
    }
  end

  def events_timeline
    render partial: "insights/charts/timeline", locals: {
      frame_id: "chart_events_timeline",
      url: timeline_insights_events_path(format: :json)
    }
  end

  def speaker_debuts
    render partial: "insights/charts/line_chart", locals: {
      frame_id: "chart_speaker_debuts",
      url: speaker_debuts_insights_calendar_index_path(format: :json),
      x_key: "year",
      y_key: "count"
    }
  end

  def talk_durations
    render partial: "insights/charts/bar_chart", locals: {
      frame_id: "chart_talk_durations",
      url: durations_insights_talks_path(format: :json),
      label_key: "label",
      value_key: "count"
    }
  end

  def talk_types
    render partial: "insights/charts/donut", locals: {
      frame_id: "chart_talk_types",
      url: kinds_insights_talks_path(format: :json)
    }
  end

  def talk_languages
    render partial: "insights/charts/bar_chart", locals: {
      frame_id: "chart_talk_languages",
      url: languages_insights_talks_path(format: :json),
      label_key: "name",
      value_key: "count",
      limit: 10
    }
  end

  def word_cloud
    render partial: "insights/charts/word_cloud", locals: {
      frame_id: "chart_word_cloud",
      url: title_words_insights_talks_path(format: :json)
    }
  end

  def prolific_speakers
    render partial: "insights/charts/lollipop", locals: {
      frame_id: "chart_prolific_speakers",
      url: prolific_insights_speakers_path(format: :json),
      label_key: "name",
      value_key: "talk_count"
    }
  end

  def connected_speakers
    render partial: "insights/charts/lollipop", locals: {
      frame_id: "chart_connected_speakers",
      url: most_connected_insights_community_index_path(format: :json),
      label_key: "name",
      value_key: "connections"
    }
  end

  def speaker_countries
    render partial: "insights/charts/bar_chart", locals: {
      frame_id: "chart_speaker_countries",
      url: speaker_countries_insights_community_index_path(format: :json),
      label_key: "name",
      value_key: "count",
      limit: 15
    }
  end

  def career_lengths
    render partial: "insights/charts/bar_chart", locals: {
      frame_id: "chart_career_lengths",
      url: career_lengths_insights_community_index_path(format: :json),
      label_key: "name",
      value_key: "career_years",
      limit: 15
    }
  end

  def topic_relationships
    render partial: "insights/charts/force_graph", locals: {
      frame_id: "chart_topic_relationships",
      url: relationships_insights_topics_path(format: :json),
      node_color: "#3b82f6",
      link_color: "#94a3b8"
    }
  end

  def speaker_network
    render partial: "insights/charts/force_graph", locals: {
      frame_id: "chart_speaker_network",
      url: co_attendance_insights_speakers_path(format: :json),
      node_color: "#8b5cf6",
      link_color: "#c4b5fd"
    }
  end

  def speaker_communities
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_speaker_communities",
      url: topic_network_insights_speakers_path(format: :json)
    }
  end

  def speaker_topics
    render partial: "insights/charts/bipartite_graph", locals: {
      frame_id: "chart_speaker_topics",
      url: topics_insights_speakers_path(format: :json)
    }
  end

  def series_longevity
    render partial: "insights/charts/bar_chart", locals: {
      frame_id: "chart_series_longevity",
      url: series_longevity_insights_community_index_path(format: :json),
      label_key: "name",
      value_key: "years_running",
      limit: 15
    }
  end

  def events_by_country
    render partial: "insights/charts/bar_chart", locals: {
      frame_id: "chart_events_by_country",
      url: by_country_insights_events_path(format: :json),
      label_key: "country_name",
      value_key: "count",
      limit: 15
    }
  end

  def topic_trends
    render partial: "insights/charts/stacked_area", locals: {
      frame_id: "chart_topic_trends",
      url: trends_insights_topics_path(format: :json)
    }
  end

  def title_linguists
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_title_linguists",
      url: title_linguists_insights_experiments_path(format: :json)
    }
  end

  def circuit_travelers
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_circuit_travelers",
      url: circuit_travelers_insights_experiments_path(format: :json)
    }
  end

  def temporal_twins
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_temporal_twins",
      url: temporal_twins_insights_experiments_path(format: :json)
    }
  end

  def duration_dna
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_duration_dna",
      url: duration_dna_insights_experiments_path(format: :json)
    }
  end

  def event_pioneers
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_event_pioneers",
      url: event_pioneers_insights_experiments_path(format: :json)
    }
  end

  def topic_evolution
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_topic_evolution",
      url: topic_evolution_insights_experiments_path(format: :json)
    }
  end

  def solo_ensemble
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_solo_ensemble",
      url: solo_ensemble_insights_experiments_path(format: :json)
    }
  end

  def trend_timing
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_trend_timing",
      url: trend_timing_insights_experiments_path(format: :json)
    }
  end

  def talk_recyclers
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_talk_recyclers",
      url: talk_recyclers_insights_experiments_path(format: :json)
    }
  end

  def seasonal_speakers
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_seasonal_speakers",
      url: seasonal_speakers_insights_experiments_path(format: :json)
    }
  end

  def conference_loyalty
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_conference_loyalty",
      url: conference_loyalty_insights_experiments_path(format: :json)
    }
  end

  def mentorship_network
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_mentorship_network",
      url: mentorship_network_insights_experiments_path(format: :json)
    }
  end

  def title_evolution
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_title_evolution",
      url: title_evolution_insights_experiments_path(format: :json)
    }
  end

  def country_clusters
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_country_clusters",
      url: country_clusters_insights_experiments_path(format: :json)
    }
  end

  def talk_affinities
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_talk_affinities",
      url: talk_affinities_insights_experiments_path(format: :json)
    }
  end

  def event_buddies
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_event_buddies",
      url: event_buddies_insights_experiments_path(format: :json)
    }
  end

  def watch_party
    render partial: "insights/charts/cluster_graph", locals: {
      frame_id: "chart_watch_party",
      url: watch_party_insights_experiments_path(format: :json)
    }
  end
end
