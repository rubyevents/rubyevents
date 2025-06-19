class SetCfpDataUpcomingEvents < ActiveRecord::Migration[8.0]
  @@cfp_data = [
    {slug: "picorubyoverflowkaigi-2025", cfp_close_date: "2025-07-15", cfp_link: "https://forms.gle/NsRZHW6MTV6aYPkF9"},
    {slug: "rubyconf-taiwan-2025", cfp_close_date: "2025-11-05", cfp_link: "https://pretalx.coscup.org/coscup-2025/cfp"},
    {slug: "friendly-rb-2025", cfp_close_date: "2025-07-01", cfp_link: "https://friendlyrb.com/cfp"},
    {slug: "kaigi-on-rails-2025", cfp_close_date: "2025-06-30", cfp_link: "https://kaigionrails.org/2025/cfp/"},
    {slug: "rocky-mountain-ruby-2025", cfp_close_date: "2025-06-30", cfp_link: "https://sessionize.com/rocky-mountain-ruby-2025/"},
    {slug: "sfruby-2025", cfp_close_date: "2025-07-13", cfp_link: "https://cfp.sfruby.com/"},
    {slug: "tiny-ruby-conf", cfp_close_date: "2025-07-30", cfp_link: "https://www.papercall.io/tinyruby"}
  ]

  def up
    @@cfp_data.each do |cfp_info|
      Event.find_by(slug: cfp_info[:slug]).update(cfp_close_date: cfp_info[:cfp_close_date], cfp_link: cfp_info[:cfp_link])
    end
  end

  def down
    @@cfp_data.each do |cfp_info|
      Event.find_by(slug: cfp_info[:slug]).update(cfp_close_date: nil, cfp_link: nil)
    end
  end
end
