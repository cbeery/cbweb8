# app/services/sync/base_service.rb
module Sync
  class BaseService
    attr_reader :sync_status, :broadcast_enabled

    def initialize(sync_status: nil, broadcast: false)
      @sync_status = sync_status || create_sync_status
      @broadcast_enabled = broadcast
    end

    def perform
      log(:info, "Starting #{source_type} sync...")
      sync_status.update!(status: 'running', started_at: Time.current)
      broadcast_status

      begin
        items = fetch_items
        
        if items.respond_to?(:size)
          # We know the total count upfront
          sync_status.update!(total_items: items.size)
          log(:info, "Found #{items.size} items to process")
          broadcast_status
          process_items_with_count(items)
        else
          # We're dealing with a stream/enumerator
          log(:info, "Processing items (total count unknown)...")
          broadcast_status
          process_items_without_count(items)
        end

        complete_sync
      rescue => e
        fail_sync(e)
        raise
      end
    end

    protected

    # Override in subclasses
    def source_type
      raise NotImplementedError
    end

    def fetch_items
      raise NotImplementedError
    end

    def process_item(item)
      raise NotImplementedError
    end

    # Optional: Override to provide item description for logging
    def describe_item(item)
      item.respond_to?(:title) ? item.title : "Item ##{sync_status.processed_items + 1}"
    end

    def log(level, message, **data)
      Rails.logger.info "[#{source_type}] #{message}" if level == :error || Rails.env.development?
      sync_status.log(level, message, **data) if sync_status
    end

    private

    def process_items_with_count(items)
      items.each_with_index do |item, index|
        process_single_item(item)
        
        sync_status.update!(processed_items: index + 1)
        
        # Broadcast progress every 5 items or at milestones
        if should_broadcast_progress?(index + 1, items.size)
          broadcast_status
        end
      end
    end

    def process_items_without_count(items)
      count = 0
      items.each do |item|
        process_single_item(item)
        
        count += 1
        sync_status.update!(processed_items: count)
        
        # Broadcast every 5 items when we don't know the total
        broadcast_status if count % 5 == 0
      end
    end

    def process_single_item(item)
      item_description = describe_item(item)
      
      begin
        result = process_item(item)
        increment_counter(result)
        
        case result
        when :created
          log(:success, "Created: #{item_description}")
        when :updated
          log(:info, "Updated: #{item_description}")
        when :skipped
          log(:info, "Skipped: #{item_description} (no changes)")
        when :failed
          log(:warning, "Failed: #{item_description}")
        end
      rescue => e
        increment_counter(:failed)
        log(:error, "Error processing #{item_description}: #{e.message}")
      end
    end

    def should_broadcast_progress?(current, total)
      return true if current == total # Always broadcast when done
      return true if current % 5 == 0 # Every 5 items
      
      # Broadcast at percentage milestones
      percentage = (current.to_f / total * 100).round
      [25, 50, 75].include?(percentage) && 
        ((current - 1).to_f / total * 100).round != percentage
    end

    def complete_sync
      sync_status.update!(
        status: 'completed',
        completed_at: Time.current
      )
      
      log(:success, "Sync completed! Created: #{sync_status.created_count}, Updated: #{sync_status.updated_count}, Failed: #{sync_status.failed_count}")
      broadcast_status
    end

    def fail_sync(error)
      sync_status.update!(
        status: 'failed',
        error_message: error.message,
        completed_at: Time.current
      )
      
      log(:error, "Sync failed: #{error.message}")
      broadcast_status
    end

    def increment_counter(result)
      case result
      when :created
        sync_status.increment!(:created_count)
      when :updated
        sync_status.increment!(:updated_count)
      when :failed
        sync_status.increment!(:failed_count)
      when :skipped
        sync_status.increment!(:skipped_count)
      end
    end

    def broadcast_status
      return unless broadcast_enabled
      
      Turbo::StreamsChannel.broadcast_update_to(
        "sync_status_#{sync_status.id}",
        target: "sync_status_#{sync_status.id}",
        partial: "admin/syncs/status_detail",
        locals: { sync_status: sync_status }
      )
    end

    def create_sync_status
      SyncStatus.create!(
        source_type: source_type,
        interactive: broadcast_enabled
      )
    end
  end
end
