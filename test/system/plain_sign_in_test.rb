# frozen_string_literal: true

require "application_system_test_case"

class PlainSignInTest < ApplicationSystemTestCase
  setup do
    Capybara.reset_sessions! if defined?(Capybara)
    Settings.disable_logins = false
    @user = users(:one)
  end

  teardown do
    Settings.reload!
  end

  test "email and password sign-in succeeds" do
    visit new_user_session_path
    fill_in "user_email", with: @user.email
    fill_in "user_password", with: "password12345"
    click_button I18n.t("devise.general.login")
    assert_text I18n.t("devise.sessions.signed_in"), wait: 10
  end
end
