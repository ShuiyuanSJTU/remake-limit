# frozen_string_literal: true

module ::RemakeLimit
  class UserDeletionLogSerializer < ::ApplicationSerializer
    attributes :id
    attributes :user_id
    attributes :username
    attributes :user_deleted_at
    attributes :ignore_limit
    attributes :silence_count
    attributes :suspend_count
  end
end