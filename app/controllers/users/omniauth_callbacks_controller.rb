class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: :google_oauth2

  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])
    
    if @user.persisted?
      # Set remember_me attribute before signing in
      @user.remember_me = true
      
      # Sign in and redirect to stored location or default
      sign_in @user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
      
      # Redirect to stored location or root
      redirect_to stored_location_for(@user) || root_path
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_user_registration_url
    end
  end

  def failure
    redirect_to root_path, alert: "Authentication failed."
  end
  
  private
  
  # Override to handle stored location properly
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || root_path
  end
end
