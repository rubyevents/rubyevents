# == Schema Information
#
# Table name: llm_requests
# Database name: primary
#
#  id            :integer          not null, primary key
#  duration      :float            not null
#  raw_response  :json             not null
#  request_hash  :string           not null, uniquely indexed
#  resource_type :string           not null, indexed => [resource_id]
#  success       :boolean          default(FALSE), not null
#  task_name     :string           default(""), not null, indexed
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  resource_id   :integer          not null, indexed => [resource_type]
#
# Indexes
#
#  index_llm_requests_on_request_hash  (request_hash) UNIQUE
#  index_llm_requests_on_resource      (resource_type,resource_id)
#  index_llm_requests_on_task_name     (task_name)
#
class LLM::Request < ApplicationRecord
  self.table_name = "llm_requests"

  belongs_to :resource, polymorphic: true

  validates :request_hash, presence: true, uniqueness: true
  validates :raw_response, presence: true
  validates :duration, presence: true
  validates :success, inclusion: {in: [true, false]}

  class << self
    def find_or_create_by_request!(request_params, resource:, task_name:, &block)
      request_hash = Digest::SHA256.hexdigest(request_params.to_json)

      if (cached_request = find_by(request_hash: request_hash, success: true))
        return cached_request.raw_response
      end

      start_time = Time.current
      response = yield
      duration = Time.current - start_time

      create!(
        request_hash: request_hash,
        raw_response: response,
        duration: duration,
        resource: resource,
        success: true # if there is an error the llm api call raise an error and we don't save the request
      ).raw_response
    end
  end
end
