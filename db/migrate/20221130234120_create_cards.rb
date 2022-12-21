# frozen_string_literal: true

class CreateCards < ActiveRecord::Migration[7.0]
  def change
    create_table :cards do |t|
      t.string :name
      t.integer :attack
      t.integer :defense

      t.timestamps
    end
  end
end
