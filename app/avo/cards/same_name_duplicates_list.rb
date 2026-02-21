class Avo::Cards::SameNameDuplicatesList < Avo::Cards::PartialCard
  self.id = "same_name_duplicates_list"
  self.label = "Same Name Duplicates"
  self.description = "Users with identical names (case-insensitive)"
  self.cols = 3
  self.rows = 2
  self.partial = "avo/cards/same_name_duplicates_list"
end
