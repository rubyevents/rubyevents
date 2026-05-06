module Events::SchedulesHelper
  def selected_schedule_day(days, today: Time.zone.today.to_s)
    days.detect { |day| day["date"] == today } || days.first
  end
end
