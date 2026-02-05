class Avo::Cards::UnavailableVideosMetric < Avo::Cards::MetricCard
  self.id = "unavailable_videos_metric"
  self.label = "Unavailable Videos"
  self.description = "Number of talks with unavailable videos"
  self.cols = 1

  def query
    result Talk.video_unavailable.count
  end
end
