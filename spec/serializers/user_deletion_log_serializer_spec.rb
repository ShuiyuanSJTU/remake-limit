# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserDeletionLogSerializer do
  let(:user) { Fabricate(:user) }
  let(:user_deletion_log) { UserDeletionLog.create_log(user) }
  let(:serializer) { described_class.new(user_deletion_log) }

  it "serializes the attributes" do
    expect(serializer.id).to eq(user_deletion_log.id)
    expect(serializer.user_id).to eq(user_deletion_log.user_id)
    expect(serializer.username).to eq(user_deletion_log.username)
    expect(serializer.user_deleted_at).to eq_time(user_deletion_log.user_deleted_at)
    expect(serializer.ignore_limit).to eq(user_deletion_log.ignore_limit)
    expect(serializer.silence_count).to eq(user_deletion_log.silence_count)
    expect(serializer.suspend_count).to eq(user_deletion_log.suspend_count)
  end

  it "should not serialize sensitive attributes" do
    serialized = serializer.as_json[:user_deletion_log]
    expect(serialized[:id]).to be_present
    expect(serialized[:email]).to be_nil
    expect(serialized[:jaccount_id]).to be_nil
    expect(serialized[:jaccount_name]).to be_nil
  end
end
