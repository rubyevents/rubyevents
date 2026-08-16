class Avo::Cards::SuspiciousUsersList < Avo::Cards::PartialCard
  self.id = "suspicious_users_list"
  self.label = "Suspicious Users"
  self.description = "Users flagged as suspicious based on signal detection"
  self.cols = 3
  self.rows = 4
  self.partial = "avo/cards/suspicious_users_list"
end
