module ::RemakeLimit
  class RemakeLimitController < ::ApplicationController
    def fetch_record_from_params
      query_args = params.permit(:user_id, :email, :jaccount_name, :jaccount_id)
      if query_args.keys.length == 0
        raise Discourse::InvalidParameters.new("At least one of user_id, email, jaccount_name, jaccount_id should be provided")
      end
      UserDeletionLog.where(query_args)
    end

    def query
      record = fetch_record_from_params
      raise Discourse::NotFound.new("Record not found") if record.length == 0
      render_serialized(record, UserDeletionLogSerializer)
    end

    def ignore
      params.require(:id)
      record = UserDeletionLog.find_by(id: params[:id])
      raise Discourse::NotFound.new("Record not found") if record.nil?
      record.ignore_limit = true
      record.save!
      render json: { success: "ok" }
    end

    def create_for_user
      params.require(:user_id)
      user = User.find_by(id: params[:user_id])
      raise Discourse::NotFound.new("User not found") if user.nil?
      record = UserDeletionLog.create_log(user, refresh_delete_time: true)
      if record.nil?
        render json: { success: "fail"} , status: :unprocessable_entity
      else
        render json: { success: "ok" }
      end
    end

    def ignore_for_user
      params.require(:user_id)
      record = UserDeletionLog.find_by(user_id: params[:user_id])
      raise Discourse::NotFound.new("Record not found") if record.nil?
      record.ignore_limit = true
      record.save!
      render json: { success: "ok", record: UserDeletionLogSerializer.new(record).as_json }
    end
  end
end