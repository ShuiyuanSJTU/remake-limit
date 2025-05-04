# frozen_string_literal: true

class AddIndexToUserDeletionLogs < ActiveRecord::Migration[7.0]
  def change
    add_index :user_deletion_logs, :email
    add_index :user_deletion_logs, :jaccount_name
    add_index :user_deletion_logs, :jaccount_id
  end
end
