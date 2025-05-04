# frozen_string_literal: true

# name: remake-limit
# about: limit user remake frequency
# version: 0.2.0
# authors: dujiajun,pangbo
# url: https://github.com/ShuiyuanSJTU/remake-limit
# required_version: 2.7.0
# transpile_js: true

module ::RemakeLimit
  PLUGIN_NAME = "remake-limit".freeze
end

enabled_site_setting :remake_limit_enabled

after_initialize do
  require_relative "app/models/user_deletion_log.rb"
  require_relative "app/serializers/user_deletion_log_serializer.rb"
  require_relative "app/controllers/remake_limit_controller.rb"

  module ::RemakeLimit
    require_relative "lib/override_users_controller.rb"
    require_relative "lib/override_trust_level_3_requirements.rb"
    require_relative "lib/override_jaccount_authenticator.rb"

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
      ::Auth::JAccountAuthenticator.prepend OverrideJAccountAuthenticator
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

  module ::RemakeLimit
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace ::RemakeLimit
    end

    Discourse::Application.routes.append { mount Engine, at: "/remake_limit" }

    Engine.routes.draw do
      constraints AdminConstraint.new do
        get "/query" => "remake_limit#query"
        delete "/id/:id" => "remake_limit#ignore"
        put "/user/:user_id" => "remake_limit#create_for_user"
        delete "/user/:user_id" => "remake_limit#ignore_for_user"
      end
    end
  end
end
