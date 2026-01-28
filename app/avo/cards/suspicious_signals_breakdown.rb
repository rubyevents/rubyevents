class Avo::Cards::SuspiciousSignalsBreakdown < Avo::Cards::PartialCard
  self.id = "suspicious_signals_breakdown"
  self.label = "Signal Breakdown"
  self.description = "Breakdown of suspicious signals across flagged users"
  self.cols = 2
  self.rows = 2
  self.partial = "avo/cards/suspicious_signals_breakdown"
end
