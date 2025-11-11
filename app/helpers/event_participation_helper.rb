module EventParticipationHelper
  def verified_attendance_badge
    ui_tooltip t("event_participation.verified_attendance") do
      fa("badge-check", class: "fill-blue-500", size: :sm)
    end
  end
end
