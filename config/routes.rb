Rails.application.routes.draw do
  devise_for :users, controllers: { 
    omniauth_callbacks: 'users/omniauth_callbacks' 
  }

  root 'home#index'

  # Home test pages (add after the root route)
  get 'home/test1', to: 'home#test1'
  get 'home/test2', to: 'home#test2'
  get 'home/test3', to: 'home#test3'
  get 'home/test4', to: 'home#test4'
  get 'home/test5', to: 'home#test5'
  get 'home/test6', to: 'home#test6'
  get 'home/test7', to: 'home#test7'
  get 'home/test8', to: 'home#test8'
  get 'home/test9', to: 'home#test9'
  get 'home/test10', to: 'home#test10'

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

    resources :movies, only: [:index, :show]

    # Spotify
    resources :spotify, controller: 'spotify', as: 'spotify_playlists' do
      collection do
        get :mixtapes
      end
      member do
        post :sync
      end
    end
    
    resources :spotify_tracks, only: [:index, :show]
    resources :spotify_artists, only: [:index, :show]

    resource :lastfm, controller: 'lastfm', only: [] do
      member do
        get :top
        get :counts
        post :sync
      end
    end

  end # namespace :admin

  # Mission Control for job monitoring (admin only)
  authenticate :user, ->(user) { user.admin? } do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  # Health check for deployment
  get "up" => "rails/health#show", as: :rails_health_check

end