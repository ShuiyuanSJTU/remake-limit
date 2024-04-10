# frozen_string_literal: true

require "rails_helper"

RSpec.describe RemakeLimit do
  describe "controller" do
    let(:user) { Fabricate(:user) }
    let(:moderator) { Fabricate(:moderator) }
    let(:admin) { Fabricate(:admin) }
    let(:record) { UserDeletionLog.find_by(email: user.email, user_id: user.id) }
    
    before(:example) do
      SiteSetting.remake_limit_enabled = true
      UserDestroyer.new(moderator).destroy(user)
      sign_in(admin)
    end
    context "can handle query" do
      it "when no params" do
        get "/remake_limit/query.json"
        expect(response.status).to eq(400)
      end
      it "when user not found" do
        get "/remake_limit/query.json", :params => { user_id: -100 }
        expect(response.status).to eq(404)
      end
      it "when using user_id " do
        get "/remake_limit/query.json", :params => { user_id: user.id }
        expect(response.status).to eq(200)
      end
      it "when using email" do
        get "/remake_limit/query.json", :params => { email: user.email }
        expect(response.status).to eq(200)
      end

      context "when find multiple records" do
        let!(:email) { user.email }
        before(:example) do
          UserDestroyer.new(moderator).destroy(user)
          another_user = Fabricate(:user, email: email)
          UserDestroyer.new(moderator).destroy(another_user)
        end
        it "should return all records" do
          get "/remake_limit/query.json", :params => { email: email }
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body).length).to eq(2)
        end
      end
    end
    context "can handle ignore" do
      it "when record not found" do
        delete "/remake_limit/id/-100.json"
        expect(response.status).to eq(404)
      end
      it "when record found" do
        delete "/remake_limit/id/#{record.id}.json"
        expect(response.status).to eq(200)
        expect(record.reload.ignore_limit).to eq(true)
      end
    end
    context "can handle create_for_user" do
      it "when user not found" do
        put "/remake_limit/-100.json"
        expect(response.status).to eq(404)
      end
      it "when user found" do
        another_user = Fabricate(:user)
        put "/remake_limit/user/#{another_user.id}.json"
        expect(response.status).to eq(200)
        new_record = UserDeletionLog.find_by(user_id: another_user.id)
        expect(new_record).to be_present
        expect(new_record.ignore_limit).to eq(false)
      end
    end
    context "can handle ignore_for_user" do
      it "when user not found" do
        delete "/remake_limit/user/-100.json"
        expect(response.status).to eq(404)
      end
      it "when user found" do
        delete "/remake_limit/user/#{user.id}.json"
        expect(response.status).to eq(200)
        expect(record.reload.ignore_limit).to eq(true)
      end
    end
  end
end