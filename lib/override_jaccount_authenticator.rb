# frozen_string_literal: true

module ::RemakeLimit
  module OverrideJAccountAuthenticator
    def after_authenticate(auth_token)
      result = super(auth_token)
      if result.failed || !result.user.nil? || !SiteSetting.remake_limit_enabled
        result
      else
        # For more detail:
        # https://github.com/ShuiyuanSJTU/discourse-omniauth-jaccount/blob/e535f263fbfa71149d14b75b141cbb4827eb5498/plugin.rb#L147-L155
        email = result.email.downcase
        jaccount_name = result.username.downcase
        jaccount_id = result.extra_data[:jaccount_uid]
        old_by_email =
          UserDeletionLog.find_latest_time_by_email(email, jaccount_name: jaccount_name)
        old_by_jaccount_id = UserDeletionLog.find_latest_time_by_jaccount_id(jaccount_id)
        # find the latest time, use compact to remove nil
        old = [old_by_email, old_by_jaccount_id].compact.max
        if !old.nil?
          time = old.to_datetime + SiteSetting.remake_limit_period.days
          if Time.now < time
            result.failed = true
            result.failed_reason =
              "您的账号正处于注册限制期，请于#{time.in_time_zone("Asia/Shanghai").strftime("%Y-%m-%d %H:%M:%S %Z")}之后再登录！"
            result.name = nil
            result.username = nil
            result.email = nil
            result.email_valid = nil
            result.extra_data = nil
            result
          end
        end
        result
      end
    end
  end
end
