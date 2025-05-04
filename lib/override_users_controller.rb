# frozen_string_literal: true

module RemakeLimit
  module OverrideUsersController
    extend ActiveSupport::Concern

    prepended do
      before_action :check_remake_limit, only: [:create]
      before_action :add_remake_limit, only: [:destroy]
      after_action :add_user_note, only: [:create]
    end

    def check_remake_limit
      if SiteSetting.remake_limit_enabled
        old = UserDeletionLog.find_latest_time_by_email(params[:email])
        if old
          time = old.to_datetime + SiteSetting.remake_limit_period.days
          if Time.now < time
            render json: {
                     success: false,
                     message:
                       "您的邮箱正处于注册限制期，请于#{time.in_time_zone("Asia/Shanghai").strftime("%Y-%m-%d %H:%M:%S %Z")}之后再注册！",
                   }
          end
        end
      end
    end

    def add_user_note
      # add penalty history to user notes
      if defined?(::DiscourseUserNotes)
        begin
          user = fetch_user_from_params(include_inactive: true)
        rescue Discourse::NotFound
          rails_logger.warn("User not found when adding user note")
          return
        end
        account_count, silence_count, suspend_count =
          UserDeletionLog.find_user_penalty_history(user)
        if account_count > 0
          ::DiscourseUserNotes.add_note(
            user,
            I18n.t(
              "remake_limit.user_note_text",
              account_count: account_count,
              silence_count: silence_count,
              suspend_count: suspend_count,
            ),
            Discourse.system_user.id,
          )
        end
      end
    end

    def add_remake_limit
      if SiteSetting.remake_limit_enabled
        user = fetch_user_from_params
        guardian.ensure_can_delete_user!(user)
        ::UserDeletionLog.create_log(user, refresh_delete_time: true)
        if defined?(::DiscourseUserNotes)
          ::DiscourseUserNotes.add_note(user, "用户尝试删除账号", Discourse.system_user.id)
        end
        if user.silenced? && !SiteSetting.remake_silenced_can_delete
          render json: { error: "您的账号处于禁言状态，无法自助删除账户，请与管理人员联系！" }, status: :unprocessable_entity
        end
      end
    end
  end
end
