# frozen_string_literal: true

class CardsController < ApplicationController
  def index
    render json: { data: ::Card::List.call.map { |c| format(c) } }
  end

  private

  def format(card)
    card.as_json(only: %i[id name value]).merge(type: format_type(card.type))
  end

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
