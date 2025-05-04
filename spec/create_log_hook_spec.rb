# frozen_string_literal: true

require "rails_helper"

RSpec.describe RemakeLimit do
  include ActiveSupport::Testing::TimeHelpers
  let(:moderator) { Fabricate(:moderator) }
  let(:user) { Fabricate(:user) }

  describe "should record user deletion log" do
    it "when moderator destroy user" do
      delete_time = 1.day.ago.beginning_of_day
      travel_to delete_time do
        UserDestroyer.new(moderator).destroy(user)
      end
      log = UserDeletionLog.find_by(email: user.email, user_id: user.id)
      expect(log).to be_present
      expect(log.user_deleted_at).to eq_time(delete_time)
      expect(log.created_at).to eq_time(delete_time)
      expect(log.ignore_limit).to eq(false)
    end
    it "when moderator anonymous user" do
      prev_email = user.email
      delete_time = 1.day.ago.beginning_of_day
      travel_to delete_time do
        UserAnonymizer.new(user, moderator).make_anonymous
      end
      log = UserDeletionLog.find_by(email: prev_email, user_id: user.id)
      expect(log).to be_present
      expect(log.user_deleted_at).to eq_time(delete_time)
      expect(log.created_at).to eq_time(delete_time)
      expect(log.ignore_limit).to eq(false)
    end
  end
end
