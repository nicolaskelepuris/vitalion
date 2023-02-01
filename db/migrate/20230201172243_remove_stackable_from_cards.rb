class RemoveStackableFromCards < ActiveRecord::Migration[7.0]
  def change
    remove_column :cards, :stackable, :boolean
  end
end
