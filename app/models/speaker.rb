# == Schema Information
#
# Table name: speakers
# Database name: primary
#
#  id              :integer          not null, primary key
#  bio             :text             default(""), not null
#  bsky            :string           default(""), not null
#  bsky_metadata   :json             not null
#  github          :string           default(""), not null, uniquely indexed
#  github_metadata :json             not null
#  linkedin        :string           default(""), not null
#  mastodon        :string           default(""), not null
#  name            :string           default(""), not null, indexed
#  pronouns        :string           default(""), not null
#  pronouns_type   :string           default("not_specified"), not null
#  slug            :string           default(""), not null, uniquely indexed
#  speakerdeck     :string           default(""), not null
#  talks_count     :integer          default(0), not null
#  twitter         :string           default(""), not null
#  website         :string           default(""), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  canonical_id    :integer          indexed
#
# Indexes
#
#  index_speakers_on_canonical_id  (canonical_id)
#  index_speakers_on_github        (github) UNIQUE WHERE github IS NOT NULL AND github != ''
#  index_speakers_on_name          (name)
#  index_speakers_on_slug          (slug) UNIQUE
#
# Foreign Keys
#
#  canonical_id  (canonical_id => speakers.id)
#
# This is a legacy model that should be removed
class Speaker < ApplicationRecord
  def title
    name
  end
end
