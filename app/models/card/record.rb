# frozen_string_literal: true

# == Schema Information
#
# Table name: cards
#
#  id         :bigint           not null, primary key
#  name       :string
#  attack     :integer
#  defense    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  stackable  :boolean          default(FALSE)
#  url        :string
#
module Card
  class Record < ApplicationRecord
    self.table_name = 'cards'
  end
end
