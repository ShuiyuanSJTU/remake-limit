# frozen_string_literal: true

# name: discourse-remake-limit
# about: limit user remake frequency
# version: 0.0.2
# authors: dujiajun,pangbo
# url: https://github.com/ShuiyuanSJTU/remake-limit
# required_version: 2.7.0
# transpile_js: true

PLUGIN_NAME ||= 'remake-limit'.freeze

enabled_site_setting :remake_limit_enabled

after_initialize do
  class ::UsersController

    before_action :check_remake_limit, only: [:create]

    def check_remake_limit
      if SiteSetting.remake_limit_enabled
        old = ::PluginStore.get(PLUGIN_NAME, params[:email])
          if old
            time = Time.parse(old) + SiteSetting.remake_limit_period * 86400
              if Time.now < time
                render json: { success: false, message: "您的邮箱正处于转生限制期，请于#{time.strftime("%Y-%m-%d %H:%M:%S %Z")}之后再注册！" }
              end
          end
      end
    end

    before_action :add_remake_limit, only: [:destroy]

    def add_remake_limit
      if SiteSetting.remake_limit_enabled
        @user = fetch_user_from_params
          guardian.ensure_can_delete_user!(@user)
          ::PluginStore.set(PLUGIN_NAME, @user.email, Time.now)
      end
    end

  end

  module OverrideUserGuardian
    def can_delete_user?(user)
      return false if is_me?(user) && user.silenced? && !SiteSetting.remake_silenced_can_delete
      super
    end
  end

  class ::Guardian
    prepend OverrideUserGuardian
  end

end
