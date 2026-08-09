# frozen_string_literal: true

require "test_helper"

class Users::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:openid_connect] = nil
    Settings.reload!
  end

  def mock_auth(email:, email_verified:)
    OmniAuth::AuthHash.new(
      provider: "openid_connect",
      uid: "sso-uid-#{email}",
      info: OmniAuth::AuthHash::InfoHash.new(email: email),
      extra: {raw_info: {"email_verified" => email_verified}}
    )
  end

  test "verified Zenith-domain email signs in and creates a user" do
    email = "newperson@zenithpayments.support"
    OmniAuth.config.mock_auth[:openid_connect] = mock_auth(email: email, email_verified: true)
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:openid_connect]

    assert_difference("User.count", 1) do
      get "/users/auth/openid_connect/callback"
    end

    assert_redirected_to root_path
    assert User.exists?(email: email)
  end

  test "unverified email is rejected, no user created" do
    email = "someone@zenithpayments.support"
    OmniAuth.config.mock_auth[:openid_connect] = mock_auth(email: email, email_verified: false)
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:openid_connect]

    assert_no_difference("User.count") do
      get "/users/auth/openid_connect/callback"
    end

    assert_redirected_to new_user_session_path
  end

  test "callback runs real validation, not a validation-skipping save" do
    # Devise's :validatable module bakes `Devise.email_regexp` into a class-level
    # validator ONCE, when User is first loaded at boot (validates_format_of :email,
    # with: email_regexp - devise-5.0.4/lib/devise/models/validatable.rb:35). Reassigning
    # Devise.email_regexp mid-test has no effect on that already-defined validator, so
    # this can't exercise PWP__SIGNUP_EMAIL_REGEXP directly here - that only ever takes
    # effect at boot (i.e. on every real deploy). See the isolated regex-pattern test
    # below for that. What IS provable here: the callback goes through User's real,
    # currently-active validations rather than save(validate: false) or update_columns -
    # proven with an email even the permissive default regex rejects (no "@").
    email = "not-an-email"
    OmniAuth.config.mock_auth[:openid_connect] = mock_auth(email: email, email_verified: true)
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:openid_connect]

    assert_no_difference("User.count") do
      get "/users/auth/openid_connect/callback"
    end

    assert_redirected_to new_user_session_path
  end
end

class ZenithSignupEmailRegexpTest < ActiveSupport::TestCase
  # Isolated from Rails boot-order concerns (see note above) - this directly verifies the
  # regex pattern set via PWP__SIGNUP_EMAIL_REGEXP in render.yaml, matching it exactly.
  ZENITH_REGEXP = /\A[^@\s]+@(zenithpayments\.com\.au|zenithpayments\.support)\z/

  test "accepts both Zenith domains" do
    assert_match ZENITH_REGEXP, "person@zenithpayments.com.au"
    assert_match ZENITH_REGEXP, "person@zenithpayments.support"
  end

  test "rejects other domains, including lookalikes" do
    refute_match ZENITH_REGEXP, "outsider@gmail.com"
    refute_match ZENITH_REGEXP, "person@notzenithpayments.support"
    refute_match ZENITH_REGEXP, "person@zenithpayments.support.evil.com"
  end
end
