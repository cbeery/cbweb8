# app/services/tmdb_service.rb
require 'httparty'

class TmdbService
  include HTTParty
  base_uri 'https://api.themoviedb.org/3'
  
  class << self
    def get_movie(tmdb_id)
      response = get("/movie/#{tmdb_id}", headers: auth_headers)
      response.parsed_response if response.success?
    end
    
    def search_movies(query)
      response = get('/search/movie', 
        headers: auth_headers,
        query: {
          query: query,
          include_adult: false
        }
      )
      
      if response.success?
        data = response.parsed_response
        data['results'] || []
      else
        []
      end
    end
    
    def get_movie_credits(tmdb_id)
      response = get("/movie/#{tmdb_id}/credits", headers: auth_headers)
      response.parsed_response if response.success?
    end
    
    def get_movie_images(tmdb_id, language: 'en')
      response = get("/movie/#{tmdb_id}/images", 
        headers: auth_headers,
        query: {
          include_image_language: "#{language},null"
        }
      )
      
      if response.success?
        data = response.parsed_response
        data['posters'] || []
      else
        []
      end
    end
    
    def poster_url(path, size: 'w500')
      return nil if path.blank?
      "https://image.tmdb.org/t/p/#{size}#{path}"
    end
    
    private
    
    def auth_headers
      {
        'Authorization' => "Bearer #{api_key}",
        'Content-Type' => 'application/json'
      }
    end
    
    def api_key
      Rails.application.credentials.dig(:tmdb, :api_key) || ENV['TMDB_API_KEY']
    end
  end
end
