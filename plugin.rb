# frozen_string_literal: true

# name: discourse-remake-limit
# about: limit user remake frequency
# version: 0.0.1
# authors: dujiajun
# url: https://github.com/ShuiyuanSJTU/remake-limit
# required_version: 2.7.0
# transpile_js: true

PLUGIN_NAME ||= 'remake-limit'.freeze
REMAKE_LIMIT_FOR_SILENCED = 'remake-limit-for-silenced'.freeze

enabled_site_setting :remake_limit_enabled

after_initialize do
  class ::UsersController

    before_action :check_remake_limit, only: [:create]
    after_action :clean_silence_diff, only: [:create]

    before_action :add_remake_limit, only: [:destroy]

    private

    def check_remake_limit
      if SiteSetting.remake_limit_enabled
        remake_at = ::PluginStore.get(PLUGIN_NAME, params[:email])
        if remake_at
          time = Time.parse(remake_at) + SiteSetting.remake_limit_period * 86400
          silence_diff = ::PluginStore.get(REMAKE_LIMIT_FOR_SILENCED, params[:email])
          if silence_diff # 补足禁言时长
            time = time + silence_diff
          end
          if Time.now < time
            render json: { success: false, message: "您正处于转生限制期，请于#{time.strftime("%Y-%m-%d %H:%M:%S")}之后再注册！" }
          end
        end
      end
    end

    def clean_silence_diff
      ::PluginStore.remove(REMAKE_LIMIT_FOR_SILENCED, params[:email])
    end

    def add_remake_limit
      if SiteSetting.remake_limit_enabled
        @user = fetch_user_from_params
        guardian.ensure_can_delete_user!(@user)
        key = @user.email
        ::PluginStore.set(PLUGIN_NAME, key, Time.now)
        if @user.silenced? # 补足禁言时长
          diff = (@user.silenced_till - Time.now).to_i
          if diff > 0
            ::PluginStore.set(REMAKE_LIMIT_FOR_SILENCED, key, diff)
          end
        end
      end
    end

  end

end
