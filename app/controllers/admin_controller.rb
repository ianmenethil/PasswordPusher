class AdminController < ApplicationController
  layout "admin"
  before_action :authenticate_user!
  before_action :require_admin

  def index
  end

  def welcome
  end

  private

  def require_admin
    unless current_user.admin?
      redirect_to root_path, alert: I18n._("Signed in as %{email}, which is not an administrator account.") % {email: current_user.email}
    end
  end
end
