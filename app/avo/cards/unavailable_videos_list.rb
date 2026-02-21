class Avo::Cards::UnavailableVideosList < Avo::Cards::PartialCard
  self.id = "unavailable_videos_list"
  self.label = "Unavailable Videos"
  self.description = "Talks with videos that are no longer available"
  self.cols = 3
  self.rows = 4
  self.partial = "avo/cards/unavailable_videos_list"
end
