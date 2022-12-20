# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ::GameChannel, type: :channel do
  before(:all) do
    Card::Record.create(name: 'card 1', attack: 2, defense: 0)
    Card::Record.create(name: 'card 2', attack: 5, defense: 0)
    Card::Record.create(name: 'card 3', attack: 15, defense: 0)
    Card::Record.create(name: 'card 4', attack: 0, defense: 1)
    Card::Record.create(name: 'card 5', attack: 0, defense: 4)
    Card::Record.create(name: 'card 6', attack: 0, defense: 1)
    Card::Record.create(name: 'card 7', attack: 0, defense: 4)
  end

  describe 'subscribe' do
    let(:current_user) { SecureRandom.uuid }
    let(:player_2) { SecureRandom.uuid }
    let(:password) { 'any password' }

    before do
      Matches[password] = ::Match::Model.new(player_1_id: current_user, observers: [::GameChannel])
      Matches[password].join(player_id: player_2)
      Matches[password].start(current_user)
    end

    describe 'success' do
      subject(:subscribe_to_game) { subscribe password: 'any password' }

      context 'when subscribing as player 1' do
        before { stub_connection current_user: current_user }

        it 'subscribes' do
          subscribe_to_game
  
          expect(subscription).to be_confirmed
          expect(subscription).to have_stream_from("match_#{password}")
        end
      end

      context 'when subscribing as player 2' do
        before { stub_connection current_user: player_2 }
        
        it 'subscribes' do
          subscribe_to_game
  
          expect(subscription).to be_confirmed
          expect(subscription).to have_stream_from("match_#{password}")
        end
      end
    end

    describe 'failures' do
      subject(:subscribe_to_game) { subscribe password: 'any password' }

      context 'when subscribing as another player' do
        let(:another_player) { SecureRandom.uuid }

        before { stub_connection current_user: another_player }
        
        it 'subscribes' do
          subscribe_to_game
  
          expect(subscription).to be_rejected
        end
      end
    end
  end
end