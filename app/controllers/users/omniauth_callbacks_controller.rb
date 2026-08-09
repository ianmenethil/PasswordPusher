# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def openid_connect
    auth = request.env["omniauth.auth"]

    # Explicit boolean cast, not Ruby truthiness: OIDC claims can arrive as the string
    # "false", which is truthy in Ruby and would silently defeat this check. raw_info
    # may expose method-style access or be a plain Hash depending on the claim shape,
    # so both are handled. This is the entire enforcement of "only verified emails get
    # in" — do not simplify it back to a bare truthiness check.
    raw_info = auth&.extra&.raw_info
    email_verified_claim = raw_info.respond_to?(:email_verified) ? raw_info.email_verified : raw_info&.[]("email_verified")
    email_verified = ActiveModel::Type::Boolean.new.cast(email_verified_claim)

    unless auth&.info&.email.present? && email_verified
      redirect_to new_user_session_path, alert: I18n._("Sign in failed: email not verified.")
      return
    end

    user = User.find_or_initialize_by(email: auth.info.email.downcase)
    user.password = Devise.friendly_token[0, 20] if user.new_record?

    # Normal Devise :validatable save, not save(validate: false) or update_columns —
    # this is what re-checks config.email_regexp (PWP__SIGNUP_EMAIL_REGEXP) on the
    # SSO-provisioned email too, so the domain lock holds even if Auth-Server's own
    # allowlist is ever misconfigured. Never bypass validation here.
    if user.save
      sign_in_and_redirect user, event: :authentication
    else
      redirect_to new_user_session_path, alert: user.errors.full_messages.to_sentence
    end
  end

  def failure
    redirect_to new_user_session_path, alert: I18n._("Sign in was cancelled or failed.")
  end
end
