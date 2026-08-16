class Avo::Cards::ReversedNameDuplicatesList < Avo::Cards::PartialCard
  self.id = "reversed_name_duplicates_list"
  self.label = "Duplicate Pairs"
  self.description = "Users with reversed name matches"
  self.cols = 3
  self.rows = 4
  self.partial = "avo/cards/reversed_name_duplicates_list"
end
