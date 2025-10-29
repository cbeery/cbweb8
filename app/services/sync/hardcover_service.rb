# app/services/sync/hardcover_service.rb
require 'httparty'

module Sync
  class HardcoverService < BaseService
    include HTTParty
    base_uri 'https://api.hardcover.app/v1/graphql'
    
    BATCH_SIZE = 20
    DEFAULT_SYNC_MONTHS = 3
    
    def initialize(sync_status: nil, broadcast: false, months_back: nil)
      super(sync_status: sync_status, broadcast: broadcast)
      @months_back = months_back || DEFAULT_SYNC_MONTHS
      @access_token = fetch_access_token
    end
    
    protected
    
    def source_type
      'hardcover'
    end
    
    def fetch_items
      log(:info, "Starting Hardcover sync - fetching books from API")
      log(:info, "Sync window: last #{@months_back} months")
      
      begin
        # Test the API connection first
        log(:info, "Testing Hardcover API connection...")
        
        # Fetch user's books with status filters
        read_books = fetch_read_books
        log(:info, "Fetched #{read_books.size} read books")
        
        currently_reading = fetch_currently_reading_books
        log(:info, "Fetched #{currently_reading.size} currently reading books")
        
        want_to_read = fetch_want_to_read_books
        log(:info, "Fetched #{want_to_read.size} want to read books")
        
        all_books = read_books + currently_reading + want_to_read
        
        log(:info, "Found #{all_books.size} books total")
      
        # Filter to recent books if specified
        if @months_back
          cutoff_date = @months_back.months.ago
          filtered_books = all_books.select do |book|
            next true if book[:status] != 'READ' # Always sync non-read books
            book[:finished_on] && Date.parse(book[:finished_on]) >= cutoff_date
          end
          log(:info, "Filtered to #{filtered_books.size} books from last #{@months_back} months")
          filtered_books
        else
          all_books
        end
      rescue => e
        log(:error, "Failed to fetch items from Hardcover: #{e.message}")
        log(:error, "Backtrace: #{e.backtrace.first(5).join("\n")}")
        raise
      end
    end
    
    def process_item(book_data)
      log(:info, "Processing book: #{book_data[:title]}")
      
      begin
        book = Book.find_or_initialize_by(hardcover_id: book_data[:id])
        
        # Determine if this is a new record
        is_new = book.new_record?
        
        # Update book attributes
        book.assign_attributes(
          title: book_data[:title],
          author: book_data[:author],
          status: map_status(book_data[:status]),
          started_on: parse_date(book_data[:started_on]),
          finished_on: parse_date(book_data[:finished_on]),
          rating: book_data[:rating],
          progress: book_data[:progress],
          isbn: book_data[:isbn],
          isbn13: book_data[:isbn13],
          goodreads_id: book_data[:goodreads_id],
          series: book_data[:series],
          series_position: book_data[:series_position],
          page_count: book_data[:page_count],
          published_year: book_data[:published_year],
          publisher: book_data[:publisher],
          description: book_data[:description],
          times_read: book_data[:times_read] || 1,
          metadata: book_data[:metadata] || {},
          last_synced_at: Time.current
        )
        
        # Save the book
        book.save!
        
        # Handle cover image if needed
        if book.should_sync_cover? && book_data[:cover_url].present?
          download_cover_image(book, book_data[:cover_url])
        end
        
        if is_new
          log(:success, "Created book: #{book.title}")
          :created
        else
          log(:info, "Updated book: #{book.title}")
          :updated
        end
        
      rescue => e
        log(:error, "Failed to process book: #{e.message}", 
            book_title: book_data[:title],
            error: e.class.name)
        :failed
      end
    end
    
    def describe_item(book_data)
      "#{book_data[:title]} by #{book_data[:author]}"
    end
    
    private
    
    def fetch_access_token
      Rails.application.credentials.dig(:hardcover, :access_token) ||
        ENV['HARDCOVER_ACCESS_TOKEN'] ||
        raise("Hardcover access token not configured")
    end
    
    def fetch_read_books
      query = <<-GRAPHQL
        query {
          me {
            books(status: READ, first: 100) {
              edges {
                node {
                  ...BookFields
                  readDates {
                    startedAt
                    finishedAt
                  }
                }
              }
            }
          }
        }
        #{book_fields_fragment}
      GRAPHQL
      
      response = execute_query(query)
      parse_books_from_response(response, 'READ')
    end
    
    def fetch_currently_reading_books
      query = <<-GRAPHQL
        query {
          me {
            books(status: CURRENTLY_READING, first: 20) {
              edges {
                node {
                  ...BookFields
                  progress
                  startedAt
                }
              }
            }
          }
        }
        #{book_fields_fragment}
      GRAPHQL
      
      response = execute_query(query)
      parse_books_from_response(response, 'CURRENTLY_READING')
    end
    
    def fetch_want_to_read_books
      query = <<-GRAPHQL
        query {
          me {
            books(status: WANT_TO_READ, first: 50) {
              edges {
                node {
                  ...BookFields
                }
              }
            }
          }
        }
        #{book_fields_fragment}
      GRAPHQL
      
      response = execute_query(query)
      parse_books_from_response(response, 'WANT_TO_READ')
    end
    
    def book_fields_fragment
      <<-GRAPHQL
        fragment BookFields on Book {
          id
          title
          author {
            name
          }
          isbn
          isbn13
          pageCount
          publishedYear
          publisher
          description
          coverUrl
          series {
            name
            position
          }
          rating
          goodreadsId
        }
      GRAPHQL
    end
    
    def execute_query(query)
      response = self.class.post(
        '',
        headers: {
          'Authorization' => "Bearer #{@access_token}",
          'Content-Type' => 'application/json'
        },
        body: { query: query }.to_json
      )
      
      unless response.success?
        raise "Hardcover API request failed: #{response.code} #{response.message}"
      end
      
      if response['errors'].present?
        raise "Hardcover GraphQL errors: #{response['errors']}"
      end
      
      response
    end
    
    def parse_books_from_response(response, status)
      edges = response.dig('data', 'me', 'books', 'edges') || []
      
      edges.map do |edge|
        node = edge['node']
        
        # Extract read dates if present
        read_dates = node['readDates']&.first || {}
        
        {
          id: node['id'],
          title: node['title'],
          author: node.dig('author', 'name'),
          status: status,
          started_on: read_dates['startedAt'] || node['startedAt'],
          finished_on: read_dates['finishedAt'],
          rating: node['rating'],
          progress: node['progress'],
          isbn: node['isbn'],
          isbn13: node['isbn13'],
          goodreads_id: node['goodreadsId'],
          series: node.dig('series', 'name'),
          series_position: node.dig('series', 'position'),
          page_count: node['pageCount'],
          published_year: node['publishedYear'],
          publisher: node['publisher'],
          description: node['description'],
          cover_url: node['coverUrl'],
          metadata: {
            hardcover_data: node
          }
        }
      end
    end
    
    def map_status(status_string)
      case status_string
      when 'READ'
        'read'
      when 'CURRENTLY_READING'
        'currently_reading'
      when 'WANT_TO_READ'
        'want_to_read'
      else
        'want_to_read'
      end
    end
    
    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string) rescue nil
    end
    
    def download_cover_image(book, cover_url)
      DownloadBookCoverJob.perform_later(book, cover_url)
    end
  end
end