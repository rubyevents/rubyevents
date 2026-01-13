class Avo::Cards::SuspiciousSummary < Avo::Cards::PartialCard
  self.id = "suspicious_summary"
  self.label = "Suspicious Users"
  self.description = "Users flagged with suspicious signals"
  self.cols = 1
  self.rows = 1
  self.partial = "avo/cards/suspicious_summary"
end
