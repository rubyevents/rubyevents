class Template
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  VIDEO_PROVIDERS = [
    "YouTube", "Vimeo, MP4", "Not Published", "Not Recorded", "Scheduled"
  ]

  attribute :title, :string
  attribute :raw_title, :string
  attribute :event_name, :string
  attribute :date, :date, default: Date.current
  attribute :announced_at, :date
  attribute :published_at, :date
  attribute :speakers, default: ""
  attribute :video_id, :string
  attribute :video_provider, :string, default: "youtube"
  attribute :language, :string, default: "english"
  attribute :track, :string
  attribute :slides_url, :string

  attribute :thumbnail_xs, :string
  attribute :thumbnail_sm, :string
  attribute :thumbnail_md, :string
  attribute :thumbnail_lg, :string
  attribute :external_player, :boolean, default: false
  attribute :external_player_url, :string

  attribute :start_cue, :time
  attribute :end_cue, :time
  attribute :description, :string

  attr_accessor :children

  validates :title, presence: true
  validates :event_name, presence: true
  validates :date, presence: true

  def initialize(attributes = {})
    @children = []
    super
  end

  def persisted?
    false
  end

  def to_param
    event_name
  end

  def children_attributes=(attributes)
    attributes.each do |i, child_params|
      @children.push(Template.new(child_params))
    end
  end

  def valid?
    parent_valid = super
    children_valid = children.map(&:valid?).all?
    children.each do |ol|
      ol.errors.each do |attribute, error|
        errors.add(:children_attributes, error)
      end
    end
    errors[:children_attributes].uniq!
    parent_valid && children_valid
  end

  def has_children?
    children.any?
  end

  def to_hash
    hash = attributes.dup
    hash["talks"] = children.map(&:to_hash) if children.any?
    transform_attributes(hash)
  end

  def transform_attributes(hash)
    %w[date announced_at published_at].each do |date_field|
      hash[date_field] = hash[date_field]&.strftime("%Y-%m-%d")
    end
    hash["video_provider"] = has_children? ? "children" : hash["video_provider"]
    hash["start_cue"] = time_to_cue(hash["start_cue"])
    hash["end_cue"] = time_to_cue(hash["end_cue"])
    hash["speakers"] = parse_speakers(hash["speakers"])
    hash.compact_blank
  end

  def to_yaml
    Array.wrap(to_hash).to_yaml.sub("---\n", "")
  end

  private

  def time_to_cue(time)
    return nil if time.blank?

    time.strftime("%H:%M:%S")
  end

  def parse_speakers(data)
    speakers.split(",").map(&:strip).reject(&:blank?) if speakers.present?
  end
end
