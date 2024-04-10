# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RemakeLimit::OverrideUsersController do
  describe "POST #create" do
    context "when remake limit is enabled" do
      before(:example) do
        UsersController.any_instance.stubs(:honeypot_value).returns(nil)
        UsersController.any_instance.stubs(:challenge_value).returns(nil)
        SiteSetting.allow_new_registrations = true
        SiteSetting.remake_limit_enabled = true
        SiteSetting.remake_limit_period = 100
        @user = Fabricate.build(:user, email: "foobar@example.com", password: "strongpassword")
      end
  
      let(:post_user_params) do
        { name: @user.name, username: @user.username, password: "strongpassword", email: @user.email }
      end

      def post_user(extra_params = {})
        post "/u.json", params: post_user_params.merge(extra_params)
      end

      it "should invoke check_remake_limit & add_user_note" do
        UsersController.any_instance.expects(:check_remake_limit).once
        UsersController.any_instance.expects(:add_user_note).once
        post_user
      end

      it "renders an error message if the email is within the remake limit period" do
        UserDeletionLog.expects(:find_latest_time_by_email)\
          .with(@user.email).returns(1.days.ago).once
        post_user
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["success"]).to eq(false)
        expect(json["message"]).to include("您的邮箱正处于注册限制期")
      end

      it "does not render an error message if the email is not within the remake limit period" do
        UserDeletionLog.expects(:find_latest_time_by_email)\
          .with(@user.email).returns(nil)
          # UserDeletionLog.expects(:find_user_penalty_history).returns([1, 2, 3])
          post_user
          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["success"]).to be_truthy
        end
        
        it "add a user note if the user has account history" do
          skip "Skip if DiscourseUserNotes is not defined" unless defined?(::DiscourseUserNotes)
          UserDeletionLog.expects(:find_latest_time_by_email)\
            .with(@user.email).returns(nil)
          UserDeletionLog.expects(:find_user_penalty_history)\
          .with(instance_of(User)).returns([1, 2, 3]).once
          post_user
          expect(
            DiscourseUserNotes.notes_for(User.find_by(username:@user.username).id).length
          ).to eq(1)
      end
    end
  end

  describe "DELETE #destroy" do
    let(:user) { Fabricate(:user) }

    before(:example) do
      SiteSetting.delete_user_self_max_post_count = 100
      SiteSetting.remake_limit_enabled = true
    end

    context "when remake limit is enabled" do
      it "should invoke create_log twice" do
        sign_in(user)
        UserDeletionLog.expects(:create_log).twice
        delete "/u/#{user.username}.json"
        expect(response.status).to eq(200)
      end

      it 'should not allow user to delete account if silenced' do
        sign_in(user)
        user.update!(silenced_till: 1.day.from_now)
        delete "/u/#{user.username}.json"
        expect(response.status).to eq(422)
      end
    end
  end
end