# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CardsController, type: :request do
  describe 'GET /cards' do
    let!(:cards) do
      [
        ::Card::Weapon.create(name: 'card 1', value: 2, url: 'url aqui', stackable: true),
        ::Card::Armor.create(name: 'card 2', value: 5),
        ::Card::HealthPotion.create(name: 'card 3', value: 15)
      ]
    end

    subject(:list_cards) { get '/cards' }

    it 'returns all cards' do
      list_cards

      expect(response.status).to eq(200)
      expect(json['data'].length).to eq(3)

      expect(json['data'][0]).to eq({
        'id' => cards[0].id,
        'name' => 'card 1',
        'value' => 2,
        'type' => 'weapon',
        'url' => 'url aqui',
        'stackable' => true
      })

      expect(json['data'][1]).to eq({
        'id' => cards[1].id,
        'name' => 'card 2',
        'value' => 5,
        'type' => 'armor',
        'url' => nil,
        'stackable' => false
      })

      expect(json['data'][2]).to eq({
        'id' => cards[2].id,
        'name' => 'card 3',
        'value' => 15,
        'type' => 'health potion',
        'url' => nil,
        'stackable' => false
      })
    end
  end
end
