# app/services/sync/test_service.rb
module Sync
  class TestService < BaseService
    # Configuration for test behavior
    SCENARIOS = {
      'quick' => { item_count: 10, delay: 0.1, failure_rate: 0 },
      'normal' => { item_count: 50, delay: 0.2, failure_rate: 0.1 },
      'slow' => { item_count: 100, delay: 0.5, failure_rate: 0.05 },
      'error_prone' => { item_count: 20, delay: 0.1, failure_rate: 0.3 },
      'will_fail' => { item_count: 10, delay: 0.1, failure_rate: 0, force_error_at: 5 },
      'unknown_count' => { item_count: rand(20..60), delay: 0.1, failure_rate: 0.05, hide_count: true }
    }.freeze
    
    def source_type
      'test'
    end
    
    protected
    
    def fetch_items
      scenario = current_scenario
      log(:info, "Using test scenario: #{scenario_name}", scenario: scenario)
      
      if scenario[:hide_count]
        # Return an enumerator to test unknown count behavior
        create_enumerator(scenario[:item_count])
      else
        # Return an array to test known count behavior
        create_array(scenario[:item_count])
      end
    end
    
    def process_item(item)
      scenario = current_scenario
      
      # Simulate work
      sleep(scenario[:delay]) if scenario[:delay] > 0
      
      # Check for forced error
      if scenario[:force_error_at] == item[:index]
        raise "Simulated error at item #{item[:index]}"
      end
      
      # Random failures based on failure rate
      if rand < scenario[:failure_rate]
        log(:warning, "Simulated failure for item", item_data: item)
        return :failed
      end
      
      # Simulate different outcomes
      case item[:type]
      when 'create'
        simulate_create(item)
        :created
      when 'update'
        simulate_update(item)
        :updated
      when 'skip'
        :skipped
      else
        # Random outcome
        [:created, :updated, :skipped].sample
      end
    end
    
    def describe_item(item)
      "Test Item ##{item[:index]}: #{item[:title]}"
    end
    
    private
    
    def scenario_name
      sync_status.metadata&.dig('scenario') || ENV['TEST_SYNC_SCENARIO'] || 'normal'
    end
    
    def current_scenario
      SCENARIOS[scenario_name] || SCENARIOS['normal']
    end
    
    def create_array(count)
      log(:info, "Generating #{count} test items...")
      
      (1..count).map do |i|
        {
          index: i,
          id: SecureRandom.uuid,
          title: generate_title(i),
          type: generate_type(i),
          value: rand(100),
          timestamp: Time.current - (count - i).hours,
          metadata: {
            batch: (i / 10) + 1,
            priority: rand(1..5)
          }
        }
      end
    end
    
    def create_enumerator(count)
      Enumerator.new do |yielder|
        batch_size = 10
        batches = (count / batch_size.to_f).ceil
        
        batches.times do |batch_num|
          log(:info, "Fetching batch #{batch_num + 1}/#{batches}...")
          sleep(0.5) # Simulate API call
          
          start_index = batch_num * batch_size + 1
          end_index = [start_index + batch_size - 1, count].min
          
          (start_index..end_index).each do |i|
            yielder << {
              index: i,
              id: SecureRandom.uuid,
              title: generate_title(i),
              type: generate_type(i),
              value: rand(100),
              timestamp: Time.current - (count - i).hours
            }
          end
        end
      end
    end
    
    def generate_title(index)
      prefixes = ['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon']
      suffixes = ['Prime', 'Secondary', 'Tertiary', 'Quantum', 'Flux']
      
      "#{prefixes.sample} #{suffixes.sample} #{index}"
    end
    
    def generate_type(index)
      case index % 10
      when 1..6 then 'create'
      when 7..9 then 'update'
      else 'skip'
      end
    end
    
    def simulate_create(item)
      # Simulate database work
      log(:success, "Created: #{item[:title]}", 
        uuid: item[:id],
        value: item[:value]
      )
      
      # Occasionally log additional info
      if item[:value] > 90
        log(:info, "High value item detected", 
          item_id: item[:id],
          value: item[:value]
        )
      end
    end
    
    def simulate_update(item)
      old_value = rand(50)
      log(:info, "Updated: #{item[:title]}", 
        uuid: item[:id],
        old_value: old_value,
        new_value: item[:value],
        delta: item[:value] - old_value
      )
    end
  end
end
