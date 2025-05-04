# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminDetailedUserSerializer do
  include ActiveSupport::Testing::TimeHelpers
  describe "#penalty_counts" do
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }
    before(:example) do
      StaffActionLogger.new(admin).log_silence_user(user)
      StaffActionLogger.new(Discourse.system_user).log_unsilence_user(user, {})
      StaffActionLogger.new(admin).log_user_suspend(user, "some reason")
      StaffActionLogger.new(Discourse.system_user).log_user_unsuspend(user)
    end

    it "should return penalty counts" do
      penalty_counts = AdminDetailedUserSerializer.new(user).penalty_counts
      expect(penalty_counts.silenced).to eq(1)
      expect(penalty_counts.suspended).to eq(1)
    end

    it "should return records long time ago" do
      travel_to 10.year.ago do
        StaffActionLogger.new(admin).log_silence_user(user)
        StaffActionLogger.new(Discourse.system_user).log_unsilence_user(user, {})
      end
      travel_to 5.year.ago do
        StaffActionLogger.new(admin).log_user_suspend(user, "some reason")
        StaffActionLogger.new(Discourse.system_user).log_user_unsuspend(user)
      end
      penalty_counts = AdminDetailedUserSerializer.new(user).penalty_counts
      expect(penalty_counts.silenced).to eq(2)
      expect(penalty_counts.suspended).to eq(2)
    end

    it "should return records for previous accounts" do
      UserDeletionLog.create!(
        user_id: -256,
        email: user.email,
        silence_count: 3,
        suspend_count: 4,
        user_deleted_at: 1.year.ago,
        ignore_limit: true,
      )
      penalty_counts = AdminDetailedUserSerializer.new(user).penalty_counts
      expect(penalty_counts.silenced).to eq(4)
      expect(penalty_counts.suspended).to eq(5)
    end

    it "should not count current user twice" do
      UserDeletionLog.create!(
        user_id: user.id,
        email: user.email,
        silence_count: 3,
        suspend_count: 4,
        user_deleted_at: 1.year.ago,
      )
      penalty_counts = AdminDetailedUserSerializer.new(user).penalty_counts
      expect(penalty_counts.silenced).to eq(1)
      expect(penalty_counts.suspended).to eq(1)
    end
  end
end
