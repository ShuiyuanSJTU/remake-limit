# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserDeletionLog, type: :model do
  let(:user) { Fabricate(:user) }

  describe ".create_log" do
    it "creates a user deletion log record" do
      expect {
        UserDeletionLog.create_log(user)
      }.to change(UserDeletionLog, :count).by(1)
    end

    it "creates a user deletion log record many times" do
      UserDeletionLog.create_log(user)
      UserDeletionLog.create_log(user)
    end

    it "sets the correct attributes in the user deletion log record" do
      UserDeletionLog.create_log(user)

      log = UserDeletionLog.last
      expect(log.user_id).to eq(user.id)
      expect(log.username).to eq(user.username)
      expect(log.email).to eq(user.email.downcase)
      # Add more expectations for other attributes if needed
    end
  end

  describe ".find_latest_time_by_email" do
    it "can handle case-insensitive email" do
      log = UserDeletionLog.create(email: user.email.downcase, user_deleted_at: Time.now)
      expect(UserDeletionLog.find_latest_time_by_email(user.email.downcase)).to eq(log.user_deleted_at)
      expect(UserDeletionLog.find_latest_time_by_email(user.email.upcase)).to eq(log.user_deleted_at)
    end

    it "returns nil if no user deletion log record is found" do
      expect(UserDeletionLog.find_latest_time_by_email("nonexistent@example.com")).to be_nil
    end

    context "when multiple records are found" do
      let!(:log1) { UserDeletionLog.create(email: user.email, user_deleted_at: 1.day.ago) }
      let!(:log2) { UserDeletionLog.create(email: user.email, user_deleted_at: 2.days.ago) }

      it "can return the last time" do
        expect(UserDeletionLog.find_latest_time_by_email(user.email)).to eq(log1.user_deleted_at)
      end

      it "can handle ignore_limit" do
        log1.update(ignore_limit: true)
        expect(UserDeletionLog.find_latest_time_by_email(user.email)).to eq(log2.user_deleted_at)
      end
    end
  end

  # Add more tests for other class methods if needed
end