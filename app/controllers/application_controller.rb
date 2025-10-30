class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :store_user_location!, if: :storable_location?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
  end

  private

  # Store the current path so we can redirect back after sign in
  def store_user_location!
    # Store the requested location for Devise to redirect back after sign in
    store_location_for(:user, request.fullpath)
  end

  # Check if we should store the location
  # - Must be a GET request
  # - Must not be an AJAX request
  # - Must be HTML format
  # - Must not be a Devise controller (avoid redirect loops)
  def storable_location?
    request.get? && 
    is_navigational_format? && 
    !devise_controller? && 
    !request.xhr?
  end

  # Override Devise's after_sign_in_path_for to respect stored location
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || super
  end
end
