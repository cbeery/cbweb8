class Admin::BaseController < ApplicationController
  before_action :authenticate_user!  # First require authentication
  before_action :authorize_admin!    # Then check admin status
  
  layout 'admin'

  private

  def authorize_admin!
    unless current_user.admin?
      redirect_to root_path, alert: "Not authorized"
    end
  end
end
