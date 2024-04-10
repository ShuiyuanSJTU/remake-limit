# frozen_string_literal: true

RSpec.describe Admin::UsersController do
  let(:delete_me) { Fabricate(:user, refresh_auto_groups: true) }
  let(:admin) { Fabricate(:admin) }
  describe "#destroy" do
    it "should invoke add_remake_limit" do
      UserDeletionLog.expects(:create_log).once
      sign_in(admin)
      delete "/admin/users/#{delete_me.id}.json"
    end
    it "should create log" do
      sign_in(admin)
      delete "/admin/users/#{delete_me.id}.json"
      log = UserDeletionLog.last
      expect(log.user_id).to eq(delete_me.id)
      expect(log.ignore_limit).to be_falsey
    end
  end
  describe "#anonymize" do
    it "should invoke add_remake_limit" do
      UserDeletionLog.expects(:create_log).once
      sign_in(admin)
      put "/admin/users/#{delete_me.id}/anonymize.json"
    end
    it "should create log" do
      sign_in(admin)
      put "/admin/users/#{delete_me.id}/anonymize.json"
      log = UserDeletionLog.last
      expect(log.user_id).to eq(delete_me.id)
      expect(log.ignore_limit).to be_falsey
    end
  end
end