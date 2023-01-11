class AddStackableToCards < ActiveRecord::Migration[7.0]
  def change
    add_column :cards, :stackable, :boolean, :default => false
  end
end
