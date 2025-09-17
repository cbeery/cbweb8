# https://claude.ai/chat/04d2d4bd-8296-472a-9b84-9c6607372053
class CreateLogEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :log_entries do |t|
      # Polymorphic association for any loggable resource
      t.references :loggable, polymorphic: true, index: true
      
      # Core fields
      t.string :category, null: false
      t.string :level, default: 'info'
      t.string :event
      t.text :message
      t.jsonb :data, default: {}
      
      # Optional actor tracking
      t.references :user, foreign_key: true
      
      t.datetime :created_at, null: false
    end
    
    # Indexes for common queries
    add_index :log_entries, [:category, :created_at]
    add_index :log_entries, [:loggable_type, :loggable_id, :created_at], 
              name: 'index_log_entries_on_loggable_and_created'
    add_index :log_entries, [:category, :level, :created_at]
  end
end
