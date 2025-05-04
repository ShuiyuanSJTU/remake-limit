# frozen_string_literal: true

# Note: 1.`email` and `jaccount_name` are stored in downcase
#         `jaccount_id` is stored in original
#       2. If `ignore_limit` is true, do not count this record when calculate cooldown time
#       3. `user_deleted_at` is the time when user is deleted,
#          do not use `created_at` to calculate cooldown time

class UserDeletionLog < ActiveRecord::Base
  JACCOUNT_PROVIDER_NAME = "jaccount".freeze
  def self.create_log(user, refresh_delete_time: true, ignore_limit: false)
    record = UserDeletionLog.find_or_initialize_by(user_id: user.id)
    record.username = user.username
    record.email = user.email.downcase
    jaccount_account = user.user_associated_accounts.find_by(provider_name: JACCOUNT_PROVIDER_NAME)
    if jaccount_account.nil?
      Rails.logger.warn("User #{user.id} has no associated jaccount")
    else
      record.jaccount_id = jaccount_account.provider_uid
      record.jaccount_name = jaccount_account.info&.[]("account")&.downcase
      if record.jaccount_name.nil?
        Rails.logger.warn(
          "User #{user.id} has an associated jaccount, but has no jaccount_name \n #{jaccount_account}",
        )
      end
    end
    pc = TrustLevel3Requirements.new(user).penalty_counts_all_time
    record.silence_count = pc.silenced
    record.suspend_count = pc.suspended
    if record.user_deleted_at.nil? && ignore_limit
      # A new record and ignore_limit is true
      record.ignore_limit = true
    end
    record.user_deleted_at = Time.now if record.user_deleted_at.nil? || refresh_delete_time
    record.save!
    record
  end

  def self.find_latest_time_by_email(email, jaccount_name: nil)
    email = email.downcase
    if jaccount_name.nil?
      jaccount_name = email.split("@").first
    elsif email.split("@").first != jaccount_name.downcase && email.split("@").last == "sjtu.edu.cn"
      Rails.logger.warn("email and jaccount_name do not match: #{email} #{jaccount_name}")
    end
    record =
      UserDeletionLog
        .where("email = ? OR jaccount_name = ?", email, jaccount_name)
        .where("user_deleted_at is NOT NULL")
        .where(ignore_limit: false)
        .order(user_deleted_at: :desc)
        .first
    record&.user_deleted_at
  end

  def self.find_latest_time_by_jaccount_id(jaccount_id)
    record =
      UserDeletionLog
        .where("jaccount_id = ?", jaccount_id)
        .where("user_deleted_at is NOT NULL")
        .where(ignore_limit: false)
        .order(user_deleted_at: :desc)
        .first
    record&.user_deleted_at
  end

  def self.find_latest_time(user)
    jaccount_account = user.user_associated_accounts.find_by(provider_name: JACCOUNT_PROVIDER_NAME)
    jaccount_id = jaccount_account.provider_uid
    jaccount_name = jaccount_account.info&.[]("account")&.downcase
    email = user.email.downcase

    record =
      UserDeletionLog
        .where(
          "email = ? OR jaccount_name = ? OR jaccount_id = ?",
          email,
          jaccount_name,
          jaccount_id,
        )
        .where("user_id != ? ", user.id)
        .where("user_deleted_at is NOT NULL")
        .where(ignore_limit: false)
        .order(user_deleted_at: :desc)
        .first
    record&.user_deleted_at
  end

  def self.find_user_penalty_history(user, ignore_jaccount_not_found: false)
    # ignore `ignore_limit` field as it is only used for cooldown time calculation
    # do not count current user

    # DEVELOPMENT NOTE: BUG && WON'T FIX
    # `user_id != ?` will always return false if user_id is NULL in DB
    #   this is an unexpected behavior
    # However, those affected records came from migration of old data
    #   and they do not have penalty counts either
    # Alough it is a bug, it can still return correct (mostly) result
    email = user.email
    jaccount_account = user.user_associated_accounts.find_by(provider_name: JACCOUNT_PROVIDER_NAME)
    if jaccount_account.nil?
      Rails.logger.warn("User #{user.id} has no jaccount_account") if !ignore_jaccount_not_found
      records = UserDeletionLog.where(email: email).where("user_id != ?", user.id)
    else
      jaccount_id = jaccount_account.provider_uid
      jaccount_name = jaccount_account.info&.[]("account")&.downcase

      if !jaccount_name.nil?
        records =
          UserDeletionLog.where(
            "email = ? OR jaccount_name = ? OR jaccount_id = ?",
            email,
            jaccount_name,
            jaccount_id,
          ).where("user_id != ? ", user.id)
      else
        records =
          UserDeletionLog.where("email = ? OR jaccount_id = ?", email, jaccount_id).where(
            "user_id != ? ",
            user.id,
          )
      end
    end
    account_count = records.count
    silence_count = records.sum(:silence_count)
    suspend_count = records.sum(:suspend_count)
    [account_count, silence_count, suspend_count]
  end
end

# == Schema Information
# Schema version: 20240327000440
#
# Table name: user_deletion_logs
#
#  id              :bigint           not null, primary key
#  user_id         :integer
#  username        :string
#  email           :string
#  jaccount_name   :string
#  jaccount_id     :string
#  silence_count   :integer
#  suspend_count   :integer
#  ignore_limit    :boolean          default(FALSE)
#  user_deleted_at :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_user_deletion_logs_on_email          (email)
#  index_user_deletion_logs_on_jaccount_id    (jaccount_id)
#  index_user_deletion_logs_on_jaccount_name  (jaccount_name)
#
