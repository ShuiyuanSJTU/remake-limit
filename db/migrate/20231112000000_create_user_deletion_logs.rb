# frozen_string_literal: true

SJTU_EMAIL = '@sjtu.edu.cn'.freeze
SJTU_ALUMNI_EMAIL = '@alumni.sjtu.edu.cn'.freeze

class CreateUserDeletionLogs < ActiveRecord::Migration[7.0]
    def up
        create_table :user_deletion_logs do |t|
            t.integer :user_id
            t.string :username
            t.string :email
            t.string :jaccount_name
            t.string :jaccount_id
            t.integer :silence_count
            t.integer :suspend_count
            t.boolean :ignore_limit, default: false
            t.datetime :user_deleted_at
    
            t.timestamps
        end
        PluginStoreRow.where(plugin_name:'remake-limit-penalty-history').each do |row|
            email = row.key
            data = JSON.parse(row.value)
            data.each do |key, value|
                user_id = key.to_i
                record = UserDeletionLog.find_or_initialize_by(
                    user_id: user_id,
                )
                record.email = email.downcase
                if email.end_with?(SJTU_EMAIL) || email.end_with?(SJTU_ALUMNI_EMAIL)
                    record.jaccount_name = email.split("@").first.downcase
                end
                record.silence_count = value['silenced']
                record.suspend_count = value['suspended']
                record.save!
            end
        end
        PluginStoreRow.where(plugin_name:'remake-limit').each do |row|
            records = UserDeletionLog.where(email: row.key.downcase)
            if records.count > 0
                records.order(user_id: :desc).first.update(user_deleted_at: row.value)
            else
                record = UserDeletionLog.create(email: row.key.downcase, user_deleted_at: row.value)
                if email.end_with?(SJTU_EMAIL) || email.end_with?(SJTU_ALUMNI_EMAIL)
                    record.jaccount_name = email.split("@").first.downcase
                end
                record.save!
            end
        end
    end
  end