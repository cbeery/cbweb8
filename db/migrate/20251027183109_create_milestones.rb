class CreateMilestones < ActiveRecord::Migration[8.0]
  def change
    create_table :milestones do |t|
      t.references :bicycle, null: false, foreign_key: true
      t.date :occurred_on, null: false
      t.string :title, null: false
      t.string :description

      t.timestamps
    end

    add_index :milestones, :occurred_on
    add_index :milestones, [:bicycle_id, :occurred_on]
  end
end
