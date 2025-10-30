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
    get "pages/index"
    get "pages/show"
    get "pages/new"
    get "pages/edit"
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

    resources :books, only: [:index, :show, :edit, :update]

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
        get :plays
        post :sync
      end
    end

    # NBA Section with its own namespace
    namespace :nba do
      root to: 'dashboard#index'  # /admin/nba
      
      resources :games do
        member do
          get :edit_modal
          patch :update_modal
        end
        collection do
          get :by_date
        end
      end
      
      resources :teams do
        member do
          post :upload_logo
        end
      end
      
      # Future routes
      # get 'data', to: 'data#index'
      # get 'stats', to: 'stats#index'
      # get 'import', to: 'import#index'
    end

    # Concerts
    resources :concerts do
      member do
        post :add_artist
        delete :remove_artist
      end
      collection do
        get :search_artists
        get :search_venues
      end
      end
    resources :concert_artists, only: [:index, :show, :new, :create]
    resources :concert_venues, only: [:index, :show, :new, :create]

    # Bicycles & Related
    namespace :bike do
      root to: 'dashboard#index'  # /admin/bike
      
      resources :bicycles do
        member do
          post :sync_strava  # Future: sync rides from Strava for this bike
        end
      end
      
      resources :rides do
        collection do
          get :calculator  # Mileage calculator
        end
      end
      
      resources :milestones

      resources :strava_activities do
        collection do
          post :sync  # Trigger Strava sync
        end
      end
    end
        
    resources :pages
        
  end # namespace :admin

  # Mission Control for job monitoring (admin only)
  authenticate :user, ->(user) { user.admin? } do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  # Health check for deployment
  get "up" => "rails/health#show", as: :rails_health_check

end