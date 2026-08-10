# frozen_string_literal: true

require "test_helper"

class Users::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  teardown do
    Settings.reload!
  end

  test "sign-in page stays reachable and hides the password form when SSO-only" do
    Settings.zenith_sso_only = true

    get new_user_session_path

    assert_response :success
    assert_select "input#user_password", count: 0
    assert_match "Sign in with Zenith SSO", response.body
  end

  test "password sign-in is blocked when SSO-only" do
    Settings.zenith_sso_only = true

    post user_session_path, params: {user: {email: @user.email, password: "password12345"}}

    assert_response :not_found
  end

  test "password sign-in still works when SSO-only is off" do
    Settings.zenith_sso_only = false

    post user_session_path, params: {user: {email: @user.email, password: "password12345"}}

    assert_redirected_to root_path
  end
end
