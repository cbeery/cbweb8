class CreatePages < ActiveRecord::Migration[8.0]
  def change
    create_table :pages do |t|
      t.string :slug, null: false
      t.text :name, null: false
      t.text :heading
      t.text :subheading
      t.date :published_on
      t.date :modified_on
      t.boolean :public, default: false, null: false
      t.boolean :show_in_index, default: false, null: false
      t.boolean :show_in_recent, default: false, null: false
      t.boolean :hide_from_search_engines, default: false, null: false
      t.boolean :hide_breadcrumbs, default: false, null: false
      t.boolean :hide_footer, default: false, null: false

      t.timestamps
    end

    add_index :pages, :slug, unique: true
    add_index :pages, :published_on
    add_index :pages, :public
    add_index :pages, [:public, :published_on]
  end
end
