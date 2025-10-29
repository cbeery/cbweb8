# lib/tasks/hardcover.rake
namespace :hardcover do
  desc "Explore book fields available"
  task explore_book_fields: :environment do
    puts "Exploring Hardcover book fields..."
    
    token = ENV['HARDCOVER_ACCESS_TOKEN'] || 
            Rails.application.credentials.dig(:hardcover, :access_token)
    
    if token.blank?
      puts "❌ No access token found!"
      exit 1
    end
    
    token = token.sub(/^bearer\s+/i, '')
    
    require 'httparty'
    
    # Try a minimal query first
    query = <<-GRAPHQL
      query {
        me {
          user_books(limit: 1) {
            book_id
            book {
              id
              title
              pages
              release_year
              release_date
              publisher
              description
              subtitle
            }
          }
        }
      }
    GRAPHQL
    
    response = HTTParty.post(
      'https://api.hardcover.app/v1/graphql',
      headers: {
        'Authorization' => "Bearer #{token}",
        'Content-Type' => 'application/json'
      },
      body: { query: query }.to_json
    )
    
    data = response.parsed_response
    
    if data['errors']
      puts "❌ Basic book query failed: #{data['errors'][0]['message']}"
    else
      puts "✅ Basic book fields work!"
    end
    
    # Try with editions for ISBN
    query2 = <<-GRAPHQL
      query {
        me {
          user_books(limit: 1) {
            book_id
            book {
              id
              title
              editions {
                id
                isbn_10
                isbn_13
                edition_format
              }
              default_physical_edition {
                isbn_10
                isbn_13
              }
            }
          }
        }
      }
    GRAPHQL
    
    response2 = HTTParty.post(
      'https://api.hardcover.app/v1/graphql',
      headers: {
        'Authorization' => "Bearer #{token}",
        'Content-Type' => 'application/json'
      },
      body: { query: query2 }.to_json
    )
    
    data2 = response2.parsed_response
    
    if data2['errors']
      puts "❌ Editions query failed: #{data2['errors'][0]['message']}"
    else
      puts "✅ Editions query works!"
      me_data = data2['data']['me']
      if me_data.is_a?(Array) && me_data.first
        user_book = me_data.first['user_books']&.first
        if user_book && user_book['book']
          book = user_book['book']
          puts "\nBook structure:"
          puts "  Title: #{book['title']}"
          puts "  Editions count: #{book['editions']&.size || 0}"
          if book['default_physical_edition']
            puts "  Default edition ISBN-10: #{book['default_physical_edition']['isbn_10']}"
            puts "  Default edition ISBN-13: #{book['default_physical_edition']['isbn_13']}"
          end
        end
      end
    end
    
    # Try the image field
    query3 = <<-GRAPHQL
      query {
        me {
          user_books(limit: 1) {
            book {
              id
              title
              image
            }
          }
        }
      }
    GRAPHQL
    
    response3 = HTTParty.post(
      'https://api.hardcover.app/v1/graphql',
      headers: {
        'Authorization' => "Bearer #{token}",
        'Content-Type' => 'application/json'
      },
      body: { query: query3 }.to_json
    )
    
    data3 = response3.parsed_response
    
    if data3['errors']
      puts "\n❌ Image field failed, trying alternatives..."
      
      # Try cover_image
      query4 = <<-GRAPHQL
        query {
          me {
            user_books(limit: 1) {
              book {
                id
                title
                cached_image {
                  url
                  id
                }
              }
            }
          }
        }
      GRAPHQL
      
      response4 = HTTParty.post(
        'https://api.hardcover.app/v1/graphql',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: { query: query4 }.to_json
      )
      
      data4 = response4.parsed_response
      if data4['errors']
        puts "  cached_image failed too: #{data4['errors'][0]['message']}"
      else
        puts "✅ cached_image field works!"
      end
    else
      puts "\n✅ Image field works!"
      me_data = data3['data']['me']
      if me_data.is_a?(Array) && me_data.first
        user_book = me_data.first['user_books']&.first
        if user_book && user_book['book']
          puts "  Image data: #{user_book['book']['image']}"
        end
      end
    end
  end
end