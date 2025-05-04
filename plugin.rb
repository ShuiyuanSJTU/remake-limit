# frozen_string_literal: true

# name: remake-limit
# about: limit user remake frequency
# version: 0.2.1
# authors: dujiajun,pangbo
# url: https://github.com/ShuiyuanSJTU/remake-limit
# required_version: 2.7.0

enabled_site_setting :remake_limit_enabled

module ::RemakeLimit
  PLUGIN_NAME = "remake-limit".freeze
end

Rails.autoloaders.main.push_dir(File.join(__dir__, "lib"), namespace: ::RemakeLimit)

require_relative "lib/engine"

after_initialize do
  module ::RemakeLimit
    module OverrideUserDestroyer
      def destroy(user, opts = {})
        ::UserDeletionLog.create_log(user, refresh_delete_time: true)
        super
      end
    end

    module OverrideUserAnonymizer
      def make_anonymous
        ::UserDeletionLog.create_log(@user, refresh_delete_time: true)
        super
      end
    end

    ::UsersController.prepend OverrideUsersController
    ::TrustLevel3Requirements.prepend OverrideTrustLevel3Requirements
    if defined?(::Auth::JAccountAuthenticator)
      ::Auth::JAccountAuthenticator.prepend OverrideJaccountAuthenticator
    end
    ::UserDestroyer.prepend OverrideUserDestroyer
    ::UserAnonymizer.prepend OverrideUserAnonymizer
  end

  add_to_serializer(:admin_detailed_user, :penalty_counts) do
    pc = TrustLevel3Requirements.new(object).penalty_counts_all_time
    penalty_counts = { "silence_count" => pc.silenced || 0, "suspend_count" => pc.suspended || 0 }
    account_count, silence_count, suspend_count =
      UserDeletionLog.find_user_penalty_history(object, ignore_jaccount_not_found: true)
    penalty_counts["silence_count"] += silence_count
    penalty_counts["suspend_count"] += suspend_count
    TrustLevel3Requirements::PenaltyCounts.new(user, penalty_counts)
  end
end
