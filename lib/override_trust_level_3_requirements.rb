# frozen_string_literal: true

module ::RemakeLimit
  module OverrideTrustLevel3Requirements
    def penalty_counts_all_time
      args = {
        user_id: @user.id,
        system_user_id: Discourse.system_user.id,
        silence_user: UserHistory.actions[:silence_user],
        unsilence_user: UserHistory.actions[:unsilence_user],
        suspend_user: UserHistory.actions[:suspend_user],
        unsuspend_user: UserHistory.actions[:unsuspend_user],
      }

      sql = <<~SQL
        SELECT
        SUM(
            CASE
              WHEN action = :silence_user THEN 1
              WHEN action = :unsilence_user AND acting_user_id != :system_user_id THEN -1
              ELSE 0
            END
          ) AS silence_count,
          SUM(
            CASE
              WHEN action = :suspend_user THEN 1
              WHEN action = :unsuspend_user AND acting_user_id != :system_user_id THEN -1
              ELSE 0
            END
          ) AS suspend_count
        FROM user_histories AS uh
        WHERE uh.target_user_id = :user_id
          AND uh.action IN (:silence_user, :suspend_user, :unsilence_user, :unsuspend_user)
      SQL

      ::TrustLevel3Requirements::PenaltyCounts.new(@user, DB.query_hash(sql, args).first)
    end
  end
end
