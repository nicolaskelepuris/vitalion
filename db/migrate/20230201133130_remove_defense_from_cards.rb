class RemoveDefenseFromCards < ActiveRecord::Migration[7.0]
  def change
    remove_column :cards, :defense, :integer
  end
end
