class Avo::Dashboards::UnavailableVideos < Avo::Dashboards::BaseDashboard
  self.id = "unavailable_videos"
  self.name = "Unavailable Videos"
  self.description = "Monitor talks with videos that are no longer available"
  self.grid_cols = 3

  def cards
    card Avo::Cards::UnavailableVideosMetric
    card Avo::Cards::UnavailableVideosByEvent
    card Avo::Cards::UnavailableVideosList
  end
end
