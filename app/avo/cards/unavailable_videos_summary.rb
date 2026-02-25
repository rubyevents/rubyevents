class Avo::Cards::UnavailableVideosSummary < Avo::Cards::PartialCard
  self.id = "unavailable_videos_summary"
  self.label = "Unavailable Videos"
  self.description = "Talks with videos no longer available"
  self.cols = 1
  self.rows = 1
  self.partial = "avo/cards/unavailable_videos_summary"
end
