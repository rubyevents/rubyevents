class User::DuplicateDetector < ActiveRecord::AssociatedObject
  extension do
    def reversed_name_duplicates
      return User.none unless name&.include?(" ")

      User
        .where(canonical_id: nil, marked_for_deletion: false)
        .where.not(id: id)
        .where(
          "LOWER(name) = LOWER(SUBSTR(:name, INSTR(:name, ' ') + 1) || ' ' || SUBSTR(:name, 1, INSTR(:name, ' ') - 1))",
          name: name
        )
    end

    def same_name_duplicates
      return User.none if name.blank?

      User
        .where(canonical_id: nil, marked_for_deletion: false)
        .where.not(id: id)
        .where("LOWER(name) = LOWER(?)", name)
    end

    scope :with_reversed_name_duplicate, -> {
      where(id: User::DuplicateDetector.reversed_name_duplicate_ids)
    }

    scope :with_same_name_duplicate, -> {
      where(id: User::DuplicateDetector.same_name_duplicate_ids)
    }

    scope :with_any_duplicate, -> {
      where(id: User::DuplicateDetector.all_duplicate_ids)
    }
  end

  def reversed_name
    return nil if user.name.blank?

    user.name.split(" ").reverse.join(" ")
  end

  def normalized_name
    return nil if user.name.blank?

    user.name.split(" ").sort.join(" ").downcase
  end

  def potential_duplicates_by_reversed_name
    user.reversed_name_duplicates
  end

  def potential_duplicates_by_normalized_name
    return User.none if user.name.blank?

    User
      .where.not(id: user.id)
      .where.not(name: [nil, ""])
      .where(canonical_id: nil)
      .where(marked_for_deletion: false)
      .select { |u| u.duplicate_detector.normalized_name == normalized_name }
  end

  def has_reversed_name_duplicate?
    potential_duplicates_by_reversed_name.exists?
  end

  def has_same_name_duplicate?
    user.same_name_duplicates.exists?
  end

  def has_any_duplicate?
    has_reversed_name_duplicate? || has_same_name_duplicate?
  end

  REVERSED_NAME_DUPLICATE_IDS_SQL = <<~SQL.squish
    SELECT DISTINCT id FROM (
      SELECT
        u1.id

      FROM
        users u1

      INNER JOIN users u2
        ON LOWER(SUBSTR(u1.name, INSTR(u1.name, ' ') + 1) || ' ' || SUBSTR(u1.name, 1, INSTR(u1.name, ' ') - 1)) = LOWER(u2.name)

      WHERE u1.id < u2.id
        AND u1.canonical_id IS NULL
        AND u2.canonical_id IS NULL
        AND u1.marked_for_deletion = 0
        AND u2.marked_for_deletion = 0
        AND INSTR(u1.name, ' ') > 0

      UNION ALL

      SELECT
        u2.id

      FROM
        users u1

      INNER JOIN users u2
        ON LOWER(SUBSTR(u1.name, INSTR(u1.name, ' ') + 1) || ' ' || SUBSTR(u1.name, 1, INSTR(u1.name, ' ') - 1)) = LOWER(u2.name)

      WHERE u1.id < u2.id
        AND u1.canonical_id IS NULL
        AND u2.canonical_id IS NULL
        AND u1.marked_for_deletion = 0
        AND u2.marked_for_deletion = 0
        AND INSTR(u1.name, ' ') > 0
    )
  SQL

  def self.reversed_name_duplicate_ids
    ActiveRecord::Base.connection.execute(REVERSED_NAME_DUPLICATE_IDS_SQL).map { |row| row["id"] }
  end

  SAME_NAME_DUPLICATE_IDS_SQL = <<~SQL.squish
    SELECT DISTINCT id FROM (
      SELECT
        u1.id

      FROM
        users u1

      INNER JOIN users u2
        ON LOWER(u1.name) = LOWER(u2.name)

      WHERE u1.id < u2.id
        AND u1.canonical_id IS NULL
        AND u2.canonical_id IS NULL
        AND u1.marked_for_deletion = 0
        AND u2.marked_for_deletion = 0
        AND u1.name IS NOT NULL
        AND u1.name != ''

      UNION ALL

      SELECT
        u2.id

      FROM
        users u1

      INNER JOIN users u2
        ON LOWER(u1.name) = LOWER(u2.name)

      WHERE u1.id < u2.id
        AND u1.canonical_id IS NULL
        AND u2.canonical_id IS NULL
        AND u1.marked_for_deletion = 0
        AND u2.marked_for_deletion = 0
        AND u1.name IS NOT NULL
        AND u1.name != ''
    )
  SQL

  def self.same_name_duplicate_ids
    ActiveRecord::Base.connection.execute(SAME_NAME_DUPLICATE_IDS_SQL).map { |row| row["id"] }
  end

  def self.all_duplicate_ids
    (reversed_name_duplicate_ids + same_name_duplicate_ids).uniq
  end

  REVERSED_NAME_DUPLICATES_SQL = <<~SQL.squish
    SELECT
      u1.id AS user1_id, u2.id AS user2_id

    FROM
      users u1

    INNER JOIN users u2
      ON LOWER(SUBSTR(u1.name, INSTR(u1.name, ' ') + 1) || ' ' || SUBSTR(u1.name, 1, INSTR(u1.name, ' ') - 1)) = LOWER(u2.name)

    WHERE u1.id < u2.id
      AND u1.canonical_id IS NULL
      AND u2.canonical_id IS NULL
      AND u1.marked_for_deletion = 0
      AND u2.marked_for_deletion = 0
      AND INSTR(u1.name, ' ') > 0
  SQL

  def self.find_all_reversed_name_duplicates
    pairs = ActiveRecord::Base.connection.execute(REVERSED_NAME_DUPLICATES_SQL)
    user_ids = pairs.flat_map { |row| [row["user1_id"], row["user2_id"]] }.uniq
    users_by_id = User.where(id: user_ids).index_by(&:id)

    pairs.map { |row| [users_by_id[row["user1_id"]], users_by_id[row["user2_id"]]] }
  end

  SAME_NAME_DUPLICATES_SQL = <<~SQL.squish
    SELECT
      u1.id AS user1_id, u2.id AS user2_id

    FROM
      users u1

    INNER JOIN users u2
      ON LOWER(u1.name) = LOWER(u2.name)

    WHERE u1.id < u2.id
      AND u1.canonical_id IS NULL
      AND u2.canonical_id IS NULL
      AND u1.marked_for_deletion = 0
      AND u2.marked_for_deletion = 0
      AND u1.name IS NOT NULL
      AND u1.name != ''
  SQL

  def self.find_all_same_name_duplicates
    pairs = ActiveRecord::Base.connection.execute(SAME_NAME_DUPLICATES_SQL)
    user_ids = pairs.flat_map { |row| [row["user1_id"], row["user2_id"]] }.uniq
    users_by_id = User.where(id: user_ids).index_by(&:id)

    pairs.map { |row| [users_by_id[row["user1_id"]], users_by_id[row["user2_id"]]] }
  end

  def self.report
    reversed_duplicates = find_all_reversed_name_duplicates
    same_name_duplicates = find_all_same_name_duplicates

    if reversed_duplicates.empty? && same_name_duplicates.empty?
      return "No duplicates found."
    end

    lines = []

    if same_name_duplicates.any?
      lines << "=== Same Name Duplicates (#{same_name_duplicates.count} pairs) ===\n"

      same_name_duplicates.each_with_index do |(user1, user2), index|
        lines << "#{index + 1}. \"#{user1.name}\" (ID: #{user1.id}) == \"#{user2.name}\" (ID: #{user2.id})"
        lines << "   User 1: talks=#{user1.talks_count}, github=#{user1.github_handle.presence || "none"}"
        lines << "   User 2: talks=#{user2.talks_count}, github=#{user2.github_handle.presence || "none"}"
        lines << ""
      end
    end

    if reversed_duplicates.any?
      lines << "=== Reversed Name Duplicates (#{reversed_duplicates.count} pairs) ===\n"

      reversed_duplicates.each_with_index do |(user1, user2), index|
        lines << "#{index + 1}. \"#{user1.name}\" (ID: #{user1.id}) <-> \"#{user2.name}\" (ID: #{user2.id})"
        lines << "   User 1: talks=#{user1.talks_count}, github=#{user1.github_handle.presence || "none"}"
        lines << "   User 2: talks=#{user2.talks_count}, github=#{user2.github_handle.presence || "none"}"
        lines << ""
      end
    end

    lines.join("\n")
  end
end
