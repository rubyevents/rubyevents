class Avo::Cards::UnavailableVideosByEvent < Avo::Cards::PartialCard
  self.id = "unavailable_videos_by_event"
  self.label = "By Event"
  self.discreet_description = "Unavailable videos grouped by event"
  self.cols = 2
  self.rows = 2
  self.partial = "avo/cards/unavailable_videos_by_event"
end
