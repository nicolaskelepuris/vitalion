class AddUrlToCards < ActiveRecord::Migration[7.0]
  def change
    add_column :cards, :url, :string
  end
end
