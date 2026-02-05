class Avo::Cards::DuplicatesSummary < Avo::Cards::PartialCard
  self.id = "duplicates_summary"
  self.label = "Duplicate Users"
  self.description = "Users with potential reversed name duplicates"
  self.cols = 1
  self.rows = 1
  self.partial = "avo/cards/duplicates_summary"
end
