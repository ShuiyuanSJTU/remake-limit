class UserDeletionLog < ActiveRecord::Base
    JACCOUNT_PROVIDER_NAME ||= 'jaccount'.freeze
    def self.create_log(user, refresh_delete_time = true)
        record = UserDeletionLog.find_or_initialize_by(user_id: user.id)
        record.username = user.username
        record.email = user.email
        jaccount_account = user.user_associated_accounts.find_by(provider_name: JACCOUNT_PROVIDER_NAME)
        record.jaccount_id = jaccount_account.provider_uid
        record.jaccount_name = jaccount_account.info&.fetch('account')
        if record.jaccount_name.nil?
            Rails.logger.warn("User #{user.id} has no jaccount_name \n #{jaccount_account}")
        end
        pc = TrustLevel3Requirements.new(user).penalty_counts_all_time
        record.silence_count = pc.silenced
        record.suspend_count = pc.suspended
        if refresh_delete_time
            record.user_deleted_at = Time.now
        end
        record.save!
    end

    def self.find_latest_time_by_email(email)
        jaccount_name= email.split("@").first
        record = UserDeletionLog.where("lower(email) = lower(?) OR lower(jaccount_name) = lower(?)",email,jaccount_name).where("user_deleted_at is NOT NULL").order(user_deleted_at: :desc).first
        record&.user_deleted_at
    end

    def self.find_latest_time(user)
        jaccount_account = user.user_associated_accounts.find_by(provider_name: JACCOUNT_PROVIDER_NAME)
        jaccount_id = jaccount_account.provider_uid
        jaccount_name = jaccount_account.info&.fetch('account')
        
        record = UserDeletionLog.where("lower(email) = lower(?) OR lower(jaccount_name) = lower(?) OR jaccount_id = ?",email,jaccount_name,jaccount_id).where("user_id != ? ",user.id).where("user_deleted_at is NOT NULL").order(user_deleted_at: :desc).first
        record&.user_deleted_at
    end

    def self.find_user_penalty_history(user)
        jaccount_account = user.user_associated_accounts.find_by(provider_name: JACCOUNT_PROVIDER_NAME)
        jaccount_id = jaccount_account.provider_uid
        jaccount_name = jaccount_account.info&.fetch('account')
        email = user.email

        records = UserDeletionLog.where("lower(email) = lower(?) OR lower(jaccount_name) = lower(?) OR jaccount_id = ?",email,jaccount_name,jaccount_id).where("user_id != ? ",user.id)
        account_count = records.count
        silence_count = records.sum(:silence_count)
        suspend_count = records.sum(:suspend_count)
        return account_count, silence_count, suspend_count
    end
end