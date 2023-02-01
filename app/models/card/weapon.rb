# == Schema Information
#
# Table name: cards
#
#  id         :bigint           not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  stackable  :boolean          default(FALSE)
#  url        :string
#  type       :string           not null
#  value      :integer          default(0), not null
#
module Card
  class Weapon < Record
  end
end
