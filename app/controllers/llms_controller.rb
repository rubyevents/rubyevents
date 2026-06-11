class LlmsController < ApplicationController
  skip_before_action :authenticate_user!

  # GET /llms.txt
  def index
    body = Rails.cache.fetch(["llms_txt", Talk.maximum(:updated_at)], expires_in: 12.hours) do
      MarkdownPresenters::LlmsIndex.new.to_text
    end

    render plain: body, content_type: "text/plain"
  end

  # GET /llms-full.txt
  def full
    body = Rails.cache.fetch(["llms_full_txt", Talk.maximum(:updated_at), Talk.count], expires_in: 12.hours) do
      MarkdownPresenters::LlmsFull.new.to_text
    end

    render plain: body, content_type: "text/plain"
  end
end
