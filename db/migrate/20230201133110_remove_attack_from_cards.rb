class RemoveAttackFromCards < ActiveRecord::Migration[7.0]
  def change
    remove_column :cards, :attack, :integer
  end
end
