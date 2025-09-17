Rails.application.routes.draw do
  devise_for :users, controllers: { 
    omniauth_callbacks: 'users/omniauth_callbacks' 
  }

  root 'home#index'

  # Admin namespace
  namespace :admin do
    root 'dashboard#index'
    
    # Test pages
    get 'test/s3', to: 'tests#s3_upload'
    post 'test/s3', to: 'tests#s3_create'
    get 'test/job', to: 'tests#active_job'
    post 'test/job', to: 'tests#trigger_job'

    # Syncs
    resources :syncs, only: [:index, :show, :create] do
      member do
        post :retry
      end
    end
    
    # Log Entries
    resources :log_entries, only: [:index, :show]

  end # namespace :admin

  # Mission Control for job monitoring (admin only)
  authenticate :user, ->(user) { user.admin? } do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  # Health check for deployment
  get "up" => "rails/health#show", as: :rails_health_check

end