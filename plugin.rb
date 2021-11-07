# frozen_string_literal: true

# name: discourse-remake-limit
# about: limit user remake frequency
# version: 0.0.1
# authors: dujiajun
# url: https://github.com/dujiajun/remake-limit
# required_version: 2.7.0
# transpile_js: true

enabled_site_setting :remake_limit_enabled

after_initialize do
    class ::UsersController
        module OverrideRemakeUserController

            def create
                if SiteSetting.remake_limit_enabled
                    old = ::PluginStore.get("remake-limit", params[:email])
                    if old
                        time = Time.parse(old) + SiteSetting.remake_limit_period * 86400
                        if Time.now < time
                            return render json: { success: false, message: "您的邮箱正处于转生限制期，请于#{time.strftime("%Y-%m-%d %H:%M:%S %Z")}之后再注册！" }
                        end
                    end
                end
                super
            end

            def destroy
                @user = fetch_user_from_params
                guardian.ensure_can_delete_user!(@user)
                if SiteSetting.remake_limit_enabled
                    ::PluginStore.set("remake-limit", @user.email, Time.now)
                end
                UserDestroyer.new(current_user).destroy(@user, delete_posts: true, context: params[:context])
                render json: success_json
            end
        end
        prepend OverrideRemakeUserController
    end
    
end
