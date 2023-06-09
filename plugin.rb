# frozen_string_literal: true

# name: remake-limit
# about: limit user remake frequency
# version: 0.0.4
# authors: dujiajun,pangbo
# url: https://github.com/ShuiyuanSJTU/remake-limit
# required_version: 2.7.0
# transpile_js: true

PLUGIN_NAME ||= 'remake-limit'.freeze
PENALTY_HISTORY_STORE_KEY ||= (PLUGIN_NAME + '-penalty-history').freeze

SJTU_EMAIL = '@sjtu.edu.cn'.freeze
SJTU_ALUMNI_EMAIL = '@alumni.sjtu.edu.cn'.freeze

enabled_site_setting :remake_limit_enabled

after_initialize do
  class ::UsersController

    before_action :check_remake_limit, only: [:create]

    def check_remake_limit
      if SiteSetting.remake_limit_enabled
        old = ::PluginStore.get(PLUGIN_NAME, params[:email])
          if old
            time = Time.parse(old) + SiteSetting.remake_limit_period.days
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
        if @user.silenced? && !SiteSetting.remake_silenced_can_delete
          render json: { error: "您的账号处于禁言状态，无法自助删除账户，请与管理人员联系！" }, status: :unprocessable_entity
        end
      end
    end
  end

  class ::TrustLevel3Requirements
    def penalty_counts_all_time
      args = {
        user_id: @user.id,
        system_user_id: Discourse.system_user.id,
        silence_user: UserHistory.actions[:silence_user],
        unsilence_user: UserHistory.actions[:unsilence_user],
        suspend_user: UserHistory.actions[:suspend_user],
        unsuspend_user: UserHistory.actions[:unsuspend_user],
      }

      sql = <<~SQL
        SELECT
        SUM(
            CASE
              WHEN action = :silence_user THEN 1
              WHEN action = :unsilence_user AND acting_user_id != :system_user_id THEN -1
              ELSE 0
            END
          ) AS silence_count,
          SUM(
            CASE
              WHEN action = :suspend_user THEN 1
              WHEN action = :unsuspend_user AND acting_user_id != :system_user_id THEN -1
              ELSE 0
            END
          ) AS suspend_count
        FROM user_histories AS uh
        WHERE uh.target_user_id = :user_id
          AND uh.action IN (:silence_user, :suspend_user, :unsilence_user, :unsuspend_user)
      SQL

      PenaltyCounts.new(@user, DB.query_hash(sql, args).first)
    end

    def save_penalty_counts
      pc = penalty_counts_all_time
      current_user_pc_hash = {
        silenced: pc.silenced,
        suspended: pc.suspended
      }
      plugin_store = PluginStore.new(PENALTY_HISTORY_STORE_KEY)
      user_email = @user.email.gsub(SJTU_ALUMNI_EMAIL, SJTU_EMAIL)
      email_history = plugin_store.get(user_email) || Hash.new
      email_history[@user.id.to_s] = current_user_pc_hash
      plugin_store.set(user_email, email_history)
    end

  end

  module OverrideUserDestroyer
    def destroy(user, opts = {})
      TrustLevel3Requirements.new(user).save_penalty_counts
      super
    end
  end

  class ::UserDestroyer
    prepend OverrideUserDestroyer
  end

  module OverrideUserAnonymizer
    def make_anonymous
      TrustLevel3Requirements.new(@user).save_penalty_counts
      super
    end
  end

  class ::UserAnonymizer
    prepend OverrideUserAnonymizer
  end

  module OverrideAdminDetailedUserSerializer
    def penalty_counts
      pc = TrustLevel3Requirements.new(object).penalty_counts_all_time
      penalty_counts = {
        "silence_count" => pc.silenced || 0,
        "suspended_count" => pc.suspended || 0
      }
      user_email = user.email.gsub(SJTU_ALUMNI_EMAIL, SJTU_EMAIL)
      penalty_counts_history = PluginStore.get(PENALTY_HISTORY_STORE_KEY, user_email) || Hash.new
      penalty_counts_history.each do |key, value|
        next if key == user.id.to_s
        penalty_counts["silence_count"] += value[:silenced]
        penalty_counts["suspended_count"] += value[:suspended]
      end
      TrustLevel3Requirements::PenaltyCounts.new(user, penalty_counts)
    end
  end

  class ::AdminDetailedUserSerializer
    prepend OverrideAdminDetailedUserSerializer
  end
  # module OverrideUserGuardian
  #   def can_delete_user?(user)
  #     return false if is_me?(user) && user.silenced? && !SiteSetting.remake_silenced_can_delete
  #     super
  #   end
  # end

  # class ::Guardian
  #   prepend OverrideUserGuardian
  # end

end
