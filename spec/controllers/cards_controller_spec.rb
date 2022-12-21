# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CardsController, type: :request do
  describe 'GET /cards' do
    before do
      ::Card::Record.create(name: 'card 1', attack: 2, defense: 0)
      ::Card::Record.create(name: 'card 2', attack: 5, defense: 0)
      ::Card::Record.create(name: 'card 3', attack: 15, defense: 0)
    end

    subject(:list_cards) { get '/cards' }

    it 'returns all cards' do
      list_cards

      expect(response.status).to eq(200)
      expect(json['data'].length).to eq(3)
      expect(json['data'][0].keys).to match_array(%w[attack defense id name])
    end
  end
end
