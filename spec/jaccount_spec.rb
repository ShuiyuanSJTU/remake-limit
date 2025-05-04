# frozen_string_literal: true

require "rails_helper"

RSpec.describe RemakeLimit::OverrideJaccountAuthenticator do
  skip "jaccount authenticator is not installed" unless defined?(::Auth::JAccountAuthenticator)

  let(:jac_uid) { "AAAAAAAA-1111-BBBB-AACC-AAAAZZZZCCCC" }
  let(:email) { "lisi@sjtu.edu.cn" }
  let(:hash) do
    OmniAuth::AuthHash.new(
      provider: "jaccount",
      uid: jac_uid,
      info: {
        account: "lisi",
        email: email,
        name: "李四",
        code: "114514",
        type: "student",
      },
      extra: {
        raw_info: {
          randominfo: "some info",
        },
      },
    )
  end
  let(:authenticator) { ::Auth::JAccountAuthenticator.new }

  before(:example) do
    SiteSetting.remake_limit_enabled = true
    SiteSetting.remake_limit_period = 100
  end

  describe "#after_authenticate" do
    it "ensure prepended successful" do
      expect(::Auth::JAccountAuthenticator.ancestors.include?(described_class)).to be_truthy
    end

    context "when invoked from authenticator" do
      it "should fails if the user is in remake limit period" do
        UserDeletionLog
          .expects(:find_latest_time_by_email)
          .with(email, jaccount_name: "lisi")
          .returns(1.days.ago)
          .once
        UserDeletionLog
          .expects(:find_latest_time_by_jaccount_id)
          .with(jac_uid)
          .returns(2.days.ago)
          .once
        result = authenticator.after_authenticate(hash)
        expect(result.failed).to be_truthy
        expect(result.user).to be_nil
        expect(result.failed_reason).to be_include("您的账号正处于注册限制期")
      end
      # it "returns the result without any modifications if current time is after the old time plus remake_limit_period" do
      #   allow(SiteSetting).to receive(:remake_limit_period).and_return(7) # Assuming remake_limit_period is 7 days
      #   allow(Time).to receive(:now).and_return(future_time + 8.days)

      #   expect(subject.after_authenticate(auth_token)).to eq(result)
      # end

      # it "modifies the result and returns it if current time is before the old time plus remake_limit_period" do
      #   allow(SiteSetting).to receive(:remake_limit_period).and_return(7) # Assuming remake_limit_period is 7 days
      #   expected_failed_reason = "您的账号正处于注册限制期，请于#{(old_time + 7.days).in_time_zone('Asia/Shanghai').strftime("%Y-%m-%d %H:%M:%S %Z")}之后再登录！"

      #   modified_result = subject.after_authenticate(auth_token)

      #   expect(modified_result.failed).to eq(true)
      #   expect(modified_result.failed_reason).to eq(expected_failed_reason)
      #   expect(modified_result.name).to be_nil
      #   expect(modified_result.username).to be_nil
      #   expect(modified_result.email).to be_nil
      #   expect(modified_result.email_valid).to be_nil
      #   expect(modified_result.extra_data).to be_nil
      # end
    end
  end
end
