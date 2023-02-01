module Card
  module Serializer
    extend self

    def call(card)
      card.as_json(only: %i[id name value url stackable]).merge(type: format_type(card.type))
    end

    private

    def format_type(type)
      case type
      when Card::Weapon.to_s
        'weapon'
      when Card::Armor.to_s
        'armor'
      when Card::HealthPotion.to_s
        'health potion'
      else
        'N/A'
      end
    end
  end
end
