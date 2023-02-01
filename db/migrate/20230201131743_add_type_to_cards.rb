class AddTypeToCards < ActiveRecord::Migration[7.0]
  def change
    add_column :cards, :type, :string, null: false
    add_column :cards, :value, :integer, null: false, default: 0
  end
end
