# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ::GameChannel, type: :channel do
  let!(:weapons) do
    [
      Card::StackableWeapon.create(name: 'stackable weapon 1', value: 3),
      Card::StackableWeapon.create(name: 'stackable weapon 2', value: 5),
      Card::StackableWeapon.create(name: 'stackable weapon 3', value: 7),
      Card::Weapon.create(name: 'weapon 5', value: 9),
      Card::Weapon.create(name: 'weapon 6', value: 11)
    ]
  end

  let!(:armors) do
    [
      Card::Armor.create(name: 'armor 1', value: 1),
      Card::Armor.create(name: 'armor 2', value: 2),
      Card::Armor.create(name: 'armor 3', value: 4),
      Card::Armor.create(name: 'armor 4', value: 6),
      Card::Armor.create(name: 'armor 5', value: 16)
    ]
  end

  let!(:health_potions) do
    [
      Card::HealthPotion.create(name: 'health potion 1', value: 5),
      Card::HealthPotion.create(name: 'health potion 2', value: 10),
      Card::HealthPotion.create(name: 'health potion 3', value: 15)
    ]
  end

  describe 'subscribe' do
    let(:current_user) { ::ApplicationCable::User.new }
    let(:player_2) { ::ApplicationCable::User.new }
    let(:password) { 'any password' }

    before do
      Matches[password] = ::Match::Model.new(player_1_id: current_user.id, observers: [::GameChannel])
      Matches[password].join(player_id: player_2.id)
      Matches[password].start
    end

    describe 'success' do
      subject(:subscribe_to_game) { subscribe password: 'any password' }

      context 'when subscribing as player 1' do
        before { stub_connection current_user: }

        it 'subscribes' do
          subscribe_to_game

          expect(subscription).to be_confirmed
          expect(subscription).to have_stream_from("match_#{password}")
          expect(subscription).to have_stream_from("notifications_#{current_user.id}")
        end
      end

      context 'when subscribing as player 2' do
        before { stub_connection current_user: player_2 }

        it 'subscribes' do
          subscribe_to_game

          expect(subscription).to be_confirmed
          expect(subscription).to have_stream_from("match_#{password}")
          expect(subscription).to have_stream_from("notifications_#{player_2.id}")
        end
      end
    end

    describe 'failures' do
      subject(:subscribe_to_game) { subscribe password: 'any password' }

      context 'when subscribing as another player' do
        let(:another_player) { ::ApplicationCable::User.new }

        before { stub_connection current_user: another_player }

        it 'subscription is rejected' do
          subscribe_to_game

          expect(subscription).to be_rejected
        end
      end
    end
  end

  describe 'start_round' do
    describe 'success' do
      let(:password) { 'any password' }
      let(:current_user) { ::ApplicationCable::User.new }
      let(:current_user_nickname) { 'a good player 1 nickname' }
      let(:second_player) { ::ApplicationCable::User.new }
      let(:second_player_nickname) { 'player 2 nickname here' }

      let(:match) do
        Matches[password] =
          ::Match::Model.new(
            player_1_id: current_user.id,
            player_1_nickname: current_user_nickname,
            observers: [::GameChannel]
        )

        Matches[password]
      end

      before do
        match.join(player_id: second_player.id, player_nickname: second_player_nickname)
        match.start
      end

      subject(:start_round) { perform :start_round, password: }

      context 'when retrieving match state as player 1' do
        before do
          stub_connection(current_user:)
          subscribe password:
        end

        it 'returns match state' do
          expect { start_round }
            .to have_broadcasted_to("notifications_#{current_user.id}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('start_round')

                player_1 = payload[:data][:player_1]

                expect(::Card::Record.pluck(:id)).to include(*player_1[:cards].pluck(:id))
                expect(player_1[:cards].length).to eq(5)

                expect(player_1[:defense_turn]).to eq(false)
                expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_1[:id]).to eq(current_user.id)
                expect(player_1[:nickname]).to eq(current_user_nickname)
                expect(player_1[:using_cards]).to eq([])

                player_2 = payload[:data][:player_2]

                expect(player_2[:cards]).to eq(nil)
                expect(player_2[:defense_turn]).to eq(false)
                expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_2[:id]).to eq(second_player.id)
                expect(player_2[:nickname]).to eq(second_player_nickname)
                expect(player_2[:using_cards]).to eq([])

                expect(player_1[:attack_turn] ^ player_2[:attack_turn]).to eq(true)
              end
            )
        end
      end

      context 'when retrieving match state as player 2' do
        before do
          stub_connection current_user: second_player
          subscribe password:
        end

        it 'returns match state' do
          expect { start_round }
            .to have_broadcasted_to("notifications_#{second_player.id}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('start_round')

                player_1 = payload[:data][:player_1]

                expect(player_1[:cards]).to eq(nil)
                expect(player_1[:defense_turn]).to eq(false)
                expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_1[:id]).to eq(current_user.id)
                expect(player_1[:nickname]).to eq(current_user_nickname)
                expect(player_1[:using_cards]).to eq([])

                player_2 = payload[:data][:player_2]

                expect(::Card::Record.pluck(:id)).to include(*player_2[:cards].pluck(:id))
                expect(player_2[:cards].length).to eq(5)

                expect(player_2[:defense_turn]).to eq(false)
                expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_2[:id]).to eq(second_player.id)
                expect(player_2[:nickname]).to eq(second_player_nickname)
                expect(player_2[:using_cards]).to eq([])
                
                expect(player_1[:attack_turn] ^ player_2[:attack_turn]).to eq(true)
              end
            )
        end
      end

      context 'after a round' do
        let(:is_player_1_attack_turn) { match.state(current_user.id)[:player_1][:attack_turn] }
        let(:attacking_player_id) { is_player_1_attack_turn ? current_user.id : second_player.id }
        let(:defending_player_id) { is_player_1_attack_turn ? second_player.id : current_user.id }

        let!(:atacking_player_cards) { [weapons[0], weapons[0], weapons[3], armors[0], health_potions[0]] }
        let!(:cards_used_in_attack_turn) { [weapons[0], weapons[0], weapons[3], armors[0]].pluck(:id) }
        
        let!(:defending_player_cards) { [armors[0], armors[0], armors[3], weapons[0], health_potions[0]] }
        let!(:cards_used_in_defense_turn) { [armors[0], armors[0], armors[3], weapons[0]].pluck(:id) }

        before do
          match
            .instance_variable_get(is_player_1_attack_turn ? :@player_1 : :@player_2)
            .instance_variable_set(:@cards, atacking_player_cards)
          
          match
            .instance_variable_get(is_player_1_attack_turn ? :@player_2 : :@player_1)
            .instance_variable_set(:@cards, defending_player_cards)

          match.attack(player_id: attacking_player_id, cards: cards_used_in_attack_turn)
          match.defend(player_id: defending_player_id, cards: cards_used_in_defense_turn)
        end

        context 'when retrieving match state as player 1' do
          before do
            stub_connection(current_user:)
            subscribe password:
          end
  
          it 'returns match state' do
            expect { start_round }
              .to have_broadcasted_to("notifications_#{current_user.id}")
              .with(
                lambda do |payload|
                  expect(payload[:method]).to eq('start_round')

                  player_1 = payload[:data][:player_1]

                  expect(::Card::Record.pluck(:id)).to include(*player_1[:cards].pluck(:id))
                  expect(player_1[:cards].length).to eq(5)

                  expect(player_1[:defense_turn]).to eq(false)
                  expect(player_1[:id]).to eq(current_user.id)
                  expect(player_1[:nickname]).to eq(current_user_nickname)
                  expect(player_1[:using_cards]).to eq([])

                  if attacking_player_id == current_user.id
                    expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                    expect(player_1[:attack_turn]).to eq(false)
                  else
                    expect(player_1[:health]).to eq(20)
                    expect(player_1[:attack_turn]).to eq(true)
                  end

                  player_2 = payload[:data][:player_2]

                  expect(player_2[:cards]).to eq(nil)
                  expect(player_2[:defense_turn]).to eq(false)
                  expect(player_2[:id]).to eq(second_player.id)
                  expect(player_2[:nickname]).to eq(second_player_nickname)
                  expect(player_2[:using_cards]).to eq([])

                  if attacking_player_id == second_player.id
                    expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                    expect(player_2[:attack_turn]).to eq(false)
                  else
                    expect(player_2[:health]).to eq(20)
                    expect(player_2[:attack_turn]).to eq(true)
                  end
                end
              )
          end
        end
  
        context 'when retrieving match state as player 2' do
          before do
            stub_connection current_user: second_player
            subscribe password:
          end
  
          it 'returns match state' do
            expect { start_round }
              .to have_broadcasted_to("notifications_#{second_player.id}")
              .with(
                lambda do |payload|
                  expect(payload[:method]).to eq('start_round')

                  player_1 = payload[:data][:player_1]

                  expect(player_1[:cards]).to eq(nil)
                  expect(player_1[:defense_turn]).to eq(false)
                  expect(player_1[:id]).to eq(current_user.id)
                  expect(player_1[:nickname]).to eq(current_user_nickname)
                  expect(player_1[:using_cards]).to eq([])

                  if attacking_player_id == current_user.id
                    expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                    expect(player_1[:attack_turn]).to eq(false)
                  else
                    expect(player_1[:health]).to eq(20)
                    expect(player_1[:attack_turn]).to eq(true)
                  end

                  player_2 = payload[:data][:player_2]

                  expect(::Card::Record.pluck(:id)).to include(*player_2[:cards].pluck(:id))
                  expect(player_2[:cards].length).to eq(5)
                  
                  expect(player_2[:defense_turn]).to eq(false)
                  expect(player_2[:id]).to eq(second_player.id)
                  expect(player_2[:nickname]).to eq(second_player_nickname)
                  expect(player_2[:using_cards]).to eq([])
                  
                  if attacking_player_id == second_player.id
                    expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                    expect(player_2[:attack_turn]).to eq(false)
                  else
                    expect(player_2[:health]).to eq(20)
                    expect(player_2[:attack_turn]).to eq(true)
                  end
                end
              )
          end
        end
      end
    end
  end

  describe 'restart_match' do
    let(:password) { 'any password' }
    let(:current_user) { ::ApplicationCable::User.new }
    let(:current_user_nickname) { 'a good player 1 nickname' }
    let(:second_player) { ::ApplicationCable::User.new }
    let(:second_player_nickname) { 'player 2 nickname here' }
    let(:player_performing_action) { [current_user, second_player].sample }

    before do
      Matches[password] =
        ::Match::Model.new(player_1_id: current_user.id, player_1_nickname: current_user_nickname,
                           observers: [::GameChannel])
      Matches[password].join(player_id: second_player.id, player_nickname: second_player_nickname)
      Matches[password].start

      stub_connection(current_user: player_performing_action)
      subscribe password:
    end

    subject(:restart_match) { perform :restart_match, password: }

    describe 'success' do
      context 'when match is finished' do        
        before { Matches[password].instance_variable_get(:@state_machine).finish }

        it 'notifies both players to start a new round' do
          expect { restart_match }
            .to have_broadcasted_to("notifications_#{current_user.id}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('start_round')

                player_1 = payload[:data][:player_1]

                expect(::Card::Record.pluck(:id)).to include(*player_1[:cards].pluck(:id))
                expect(player_1[:cards].length).to eq(5)

                expect(player_1[:defense_turn]).to eq(false)
                expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_1[:id]).to eq(current_user.id)
                expect(player_1[:nickname]).to eq(current_user_nickname)
                expect(player_1[:using_cards]).to eq([])

                player_2 = payload[:data][:player_2]

                expect(player_2[:cards]).to eq(nil)
                expect(player_2[:defense_turn]).to eq(false)
                expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_2[:id]).to eq(second_player.id)
                expect(player_2[:nickname]).to eq(second_player_nickname)
                expect(player_2[:using_cards]).to eq([])

                expect(player_1[:attack_turn] ^ player_2[:attack_turn]).to eq(true)
              end
            )
            .and have_broadcasted_to("notifications_#{second_player.id}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('start_round')

                player_1 = payload[:data][:player_1]

                expect(player_1[:cards]).to eq(nil)
                expect(player_1[:defense_turn]).to eq(false)
                expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_1[:id]).to eq(current_user.id)
                expect(player_1[:nickname]).to eq(current_user_nickname)
                expect(player_1[:using_cards]).to eq([])

                player_2 = payload[:data][:player_2]

                expect(::Card::Record.pluck(:id)).to include(*player_2[:cards].pluck(:id))
                expect(player_2[:cards].length).to eq(5)

                expect(player_2[:defense_turn]).to eq(false)
                expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_2[:id]).to eq(second_player.id)
                expect(player_2[:nickname]).to eq(second_player_nickname)
                expect(player_2[:using_cards]).to eq([])
                
                expect(player_1[:attack_turn] ^ player_2[:attack_turn]).to eq(true)
              end
            )
        end
      end
    end

    describe 'failures' do
      context 'when match is not finished' do
        it 'notifies both players to start a new round' do
          expect { restart_match }
            .to have_broadcasted_to("notifications_#{player_performing_action.id}")
            .with(method: "start_round", error: "Can't restart the match")
        end
      end
    end
  end

  describe 'attack' do
    describe 'success' do
      let(:password) { 'any password' }
      let(:current_user) { ::ApplicationCable::User.new }
      let(:current_user_nickname) { 'a good player 1 nickname' }
      let(:second_player) { ::ApplicationCable::User.new }
      let(:second_player_nickname) { 'player 2 nickname here' }
      let!(:match) do
        Matches[password] = ::Match::Model.new(
          player_1_id: current_user.id,
          player_1_nickname: current_user_nickname,
          observers: [::GameChannel]
        )

        Matches[password].join(player_id: second_player.id, player_nickname: second_player_nickname)
        Matches[password].start
        
        Matches[password]
      end

      let(:is_player_1_attack_turn) { match.state(current_user.id)[:player_1][:attack_turn] }
      let(:attacking_player_id) { is_player_1_attack_turn ? current_user.id : second_player.id }
      let(:defending_player_id) { is_player_1_attack_turn ? second_player.id : current_user.id }

      let!(:atacking_player_cards) { [weapons[0], weapons[0], weapons[3], armors[0], health_potions[0]] }
      let!(:cards_used_in_attack_turn) { [weapons[0], weapons[0], weapons[3], armors[0]].pluck(:id) }
      let!(:valid_used_cards) { [weapons[0], weapons[3]].map { |c| ::Card::Serializer.call(c) } }

      before do
        match
          .instance_variable_get(is_player_1_attack_turn ? :@player_1 : :@player_2)
          .instance_variable_set(:@cards, atacking_player_cards)
      end

      before do
        stub_connection(current_user: is_player_1_attack_turn ? current_user : second_player)
        subscribe password:
      end

      subject(:attack) { perform :attack, cards: cards_used_in_attack_turn }

      context 'when player attacks using 1 or more attack cards' do
        it 'returns match state to player one' do
          expect { attack }
            .to have_broadcasted_to("notifications_#{current_user.id}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('end_attack_turn')

                player_1 = payload[:data][:player_1]

                expect(::Card::Record.pluck(:id)).to include(*player_1[:cards].pluck(:id))

                expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_1[:id]).to eq(current_user.id)
                expect(player_1[:nickname]).to eq(current_user_nickname)
                expect(player_1[:attack_turn]).to eq(false)

                if attacking_player_id == current_user.id
                  expect(player_1[:cards].length).to eq(5 - valid_used_cards.length)
                  expect(player_1[:using_cards]).to match_array(valid_used_cards)
                  expect(player_1[:defense_turn]).to eq(false)
                else
                  expect(player_1[:cards].length).to eq(5)
                  expect(player_1[:using_cards]).to eq([])
                  expect(player_1[:defense_turn]).to eq(true)
                end

                player_2 = payload[:data][:player_2]

                expect(player_2[:cards]).to eq(nil)
                expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_2[:id]).to eq(second_player.id)
                expect(player_2[:nickname]).to eq(second_player_nickname)
                expect(player_2[:attack_turn]).to eq(false)

                if attacking_player_id == second_player.id
                  expect(player_2[:using_cards]).to match_array(valid_used_cards)
                  expect(player_2[:defense_turn]).to eq(false)
                else
                  expect(player_2[:using_cards]).to eq([])
                  expect(player_2[:defense_turn]).to eq(true)
                end
              end
            )
        end
  
        it 'returns match state to player two' do
          expect { attack }
            .to have_broadcasted_to("notifications_#{second_player.id}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('end_attack_turn')

                player_1 = payload[:data][:player_1]
                
                expect(player_1[:cards]).to eq(nil)
                expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_1[:id]).to eq(current_user.id)
                expect(player_1[:nickname]).to eq(current_user_nickname)
                expect(player_1[:attack_turn]).to eq(false)

                if attacking_player_id == current_user.id
                  expect(player_1[:using_cards]).to match_array(valid_used_cards)
                  expect(player_1[:defense_turn]).to eq(false)
                else
                  expect(player_1[:using_cards]).to eq([])
                  expect(player_1[:defense_turn]).to eq(true)
                end

                player_2 = payload[:data][:player_2]

                expect(::Card::Record.pluck(:id)).to include(*player_2[:cards].pluck(:id))

                expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_2[:id]).to eq(second_player.id)
                expect(player_2[:nickname]).to eq(second_player_nickname)
                expect(player_1[:attack_turn]).to eq(false)

                if attacking_player_id == second_player.id
                  expect(player_2[:cards].length).to eq(5 - valid_used_cards.length)
                  expect(player_2[:using_cards]).to match_array(valid_used_cards)
                  expect(player_2[:defense_turn]).to eq(false)
                else
                  expect(player_2[:cards].length).to eq(5)
                  expect(player_2[:using_cards]).to eq([])
                  expect(player_2[:defense_turn]).to eq(true)
                end
              end
            )
        end

        context 'when using health potion' do
          let!(:atacking_player_cards) { [weapons[0], weapons[0], armors[0], health_potions[0], health_potions[1]] }
          let!(:cards_used_in_attack_turn) { atacking_player_cards.pluck(:id) }
          let!(:valid_used_cards) { [health_potions[1]].map { |c| ::Card::Serializer.call(c) } }

          before do
            match
              .instance_variable_get(:@player_1)
              .instance_variable_set(:@health, 3)
              
            match
              .instance_variable_get(:@player_2)
              .instance_variable_set(:@health, 5)
          end

          it 'returns match state to player one' do
            expect { attack }
              .to have_broadcasted_to("notifications_#{current_user.id}")
              .with(
                lambda do |payload|
                  expect(payload[:method]).to eq('start_round')
  
                  player_1 = payload[:data][:player_1]
  
                  expect(::Card::Record.pluck(:id)).to include(*player_1[:cards].pluck(:id))
                  expect(player_1[:cards].length).to eq(5)
  
                  expect(player_1[:id]).to eq(current_user.id)
                  expect(player_1[:nickname]).to eq(current_user_nickname)
                  expect(player_1[:defense_turn]).to eq(false)
                  expect(player_1[:using_cards]).to eq([])
  
                  if attacking_player_id == current_user.id
                    expect(player_1[:health]).to eq(13)
                    expect(player_1[:attack_turn]).to eq(false)
                  else
                    expect(player_1[:health]).to eq(3)
                    expect(player_1[:attack_turn]).to eq(true)
                  end
  
                  player_2 = payload[:data][:player_2]
  
                  expect(player_2[:cards]).to eq(nil)
                  expect(player_2[:id]).to eq(second_player.id)
                  expect(player_2[:nickname]).to eq(second_player_nickname)
                  expect(player_2[:defense_turn]).to eq(false)
                  expect(player_2[:using_cards]).to eq([])
  
                  if attacking_player_id == second_player.id
                    expect(player_2[:health]).to eq(15)
                    expect(player_2[:attack_turn]).to eq(false)
                  else
                    expect(player_2[:health]).to eq(5)
                    expect(player_2[:attack_turn]).to eq(true)
                  end
                end
              )
          end
    
          it 'returns match state to player two' do
            expect { attack }
              .to have_broadcasted_to("notifications_#{second_player.id}")
              .with(
                lambda do |payload|
                  expect(payload[:method]).to eq('start_round')
  
                  player_1 = payload[:data][:player_1]  
                  
                  expect(player_1[:cards]).to eq(nil)
                  expect(player_1[:id]).to eq(current_user.id)
                  expect(player_1[:nickname]).to eq(current_user_nickname)
                  expect(player_1[:defense_turn]).to eq(false)
                  expect(player_1[:using_cards]).to eq([])
  
                  if attacking_player_id == current_user.id
                    expect(player_1[:health]).to eq(13)
                    expect(player_1[:attack_turn]).to eq(false)
                  else
                    expect(player_1[:health]).to eq(3)
                    expect(player_1[:attack_turn]).to eq(true)
                  end
  
                  player_2 = payload[:data][:player_2]
  
                  expect(::Card::Record.pluck(:id)).to include(*player_2[:cards].pluck(:id))
                  expect(player_2[:cards].length).to eq(5)

                  expect(player_2[:id]).to eq(second_player.id)
                  expect(player_2[:nickname]).to eq(second_player_nickname)
                  expect(player_2[:defense_turn]).to eq(false)
                  expect(player_2[:using_cards]).to eq([])
  
                  if attacking_player_id == second_player.id
                    expect(player_2[:health]).to eq(15)
                    expect(player_2[:attack_turn]).to eq(false)
                  else
                    expect(player_2[:health]).to eq(5)
                    expect(player_2[:attack_turn]).to eq(true)
                  end
                end
              )
          end
        end
      end
      
      context 'when player attacks using 0 attack cards' do
        let!(:cards_used_in_attack_turn) { [[], [armors[0], armors[3]]].sample.pluck(:id) }

        it 'returns match state to player one' do
          expect { attack }
            .to have_broadcasted_to("notifications_#{current_user.id}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('start_round')

                player_1 = payload[:data][:player_1]

                expect(::Card::Record.pluck(:id)).to include(*player_1[:cards].pluck(:id))

                expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_1[:id]).to eq(current_user.id)
                expect(player_1[:nickname]).to eq(current_user_nickname)
                expect(player_1[:defense_turn]).to eq(false)
                expect(player_1[:using_cards]).to eq([])

                if attacking_player_id == current_user.id
                  expect(player_1[:cards].length).to eq(6)
                  expect(player_1[:attack_turn]).to eq(false)

                  remaining_skips_with_attack_cards = match.instance_variable_get(:@player_1)
                                                           .instance_variable_get(:@remaining_skips_with_attack_cards)
                  expect(remaining_skips_with_attack_cards).to eq(1)
                else
                  expect(player_1[:cards].length).to eq(5)
                  expect(player_1[:attack_turn]).to eq(true)
                end

                player_2 = payload[:data][:player_2]

                expect(player_2[:cards]).to eq(nil)
                expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_2[:id]).to eq(second_player.id)
                expect(player_2[:nickname]).to eq(second_player_nickname)
                expect(player_2[:defense_turn]).to eq(false)
                expect(player_2[:using_cards]).to eq([])

                if attacking_player_id == second_player.id
                  expect(player_2[:attack_turn]).to eq(false)
                else
                  expect(player_2[:attack_turn]).to eq(true)
                end
              end
            )
        end
  
        it 'returns match state to player two' do
          expect { attack }
            .to have_broadcasted_to("notifications_#{second_player.id}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('start_round')

                player_1 = payload[:data][:player_1]

                expect(player_1[:cards]).to eq(nil)
                expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_1[:id]).to eq(current_user.id)
                expect(player_1[:nickname]).to eq(current_user_nickname)
                expect(player_1[:defense_turn]).to eq(false)
                expect(player_1[:using_cards]).to eq([])

                if attacking_player_id == current_user.id
                  expect(player_1[:attack_turn]).to eq(false)
                else
                  expect(player_1[:attack_turn]).to eq(true)
                end

                player_2 = payload[:data][:player_2]

                expect(::Card::Record.pluck(:id)).to include(*player_2[:cards].pluck(:id))
                
                expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_2[:id]).to eq(second_player.id)
                expect(player_2[:nickname]).to eq(second_player_nickname)
                expect(player_2[:defense_turn]).to eq(false)
                expect(player_2[:using_cards]).to eq([])

                if attacking_player_id == second_player.id
                  expect(player_2[:cards].length).to eq(6)
                  expect(player_2[:attack_turn]).to eq(false)
                  
                  remaining_skips_with_attack_cards = match.instance_variable_get(:@player_2)
                                                           .instance_variable_get(:@remaining_skips_with_attack_cards)
                  expect(remaining_skips_with_attack_cards).to eq(1)
                else
                  expect(player_2[:cards].length).to eq(5)
                  expect(player_2[:attack_turn]).to eq(true)
                end
              end
            )
        end

        context 'and player can not skip having attack cards' do
          before do
            match
              .instance_variable_get(is_player_1_attack_turn ? :@player_1 : :@player_2)
              .instance_variable_set(:@remaining_skips_with_attack_cards, 0)
          end

          it 'returns match state to player one' do
            expect { attack }
              .to have_broadcasted_to("notifications_#{current_user.id}")
              .with(
                lambda do |payload|
                  expect(payload[:method]).to eq('start_round')
  
                  player_1 = payload[:data][:player_1]
  
                  expect(::Card::Record.pluck(:id)).to include(*player_1[:cards].pluck(:id))
                  expect(player_1[:cards].length).to eq(5)
  
                  expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                  expect(player_1[:id]).to eq(current_user.id)
                  expect(player_1[:nickname]).to eq(current_user_nickname)
                  expect(player_1[:defense_turn]).to eq(false)
                  expect(player_1[:using_cards]).to eq([])
  
                  if attacking_player_id == current_user.id
                    expect(player_1[:attack_turn]).to eq(false)
                    expect(player_1[:remaining_skips_with_attack_cards]).to eq(0)
                  else
                    expect(player_1[:attack_turn]).to eq(true)
                    expect(player_1[:remaining_skips_with_attack_cards]).to eq(2)
                  end
  
                  player_2 = payload[:data][:player_2]
  
                  expect(player_2[:cards]).to eq(nil)
                  expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                  expect(player_2[:id]).to eq(second_player.id)
                  expect(player_2[:nickname]).to eq(second_player_nickname)
                  expect(player_2[:defense_turn]).to eq(false)
                  expect(player_2[:using_cards]).to eq([])
                  expect(player_2[:remaining_skips_with_attack_cards]).to eq(nil)
  
                  if attacking_player_id == second_player.id
                    expect(player_2[:attack_turn]).to eq(false)
                  else
                    expect(player_2[:attack_turn]).to eq(true)
                  end
                end
              )
          end
    
          it 'returns match state to player two' do
            expect { attack }
              .to have_broadcasted_to("notifications_#{second_player.id}")
              .with(
                lambda do |payload|
                  expect(payload[:method]).to eq('start_round')
  
                  player_1 = payload[:data][:player_1]
  
                  expect(player_1[:cards]).to eq(nil)
                  expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                  expect(player_1[:id]).to eq(current_user.id)
                  expect(player_1[:nickname]).to eq(current_user_nickname)
                  expect(player_1[:defense_turn]).to eq(false)
                  expect(player_1[:using_cards]).to eq([])
                  expect(player_1[:remaining_skips_with_attack_cards]).to eq(nil)
  
                  if attacking_player_id == current_user.id
                    expect(player_1[:attack_turn]).to eq(false)
                  else
                    expect(player_1[:attack_turn]).to eq(true)
                  end
  
                  player_2 = payload[:data][:player_2]
  
                  expect(::Card::Record.pluck(:id)).to include(*player_2[:cards].pluck(:id))
                  expect(player_2[:cards].length).to eq(5)
                  
                  expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                  expect(player_2[:id]).to eq(second_player.id)
                  expect(player_2[:nickname]).to eq(second_player_nickname)
                  expect(player_2[:defense_turn]).to eq(false)
                  expect(player_2[:using_cards]).to eq([])
  
                  if attacking_player_id == second_player.id
                    expect(player_2[:attack_turn]).to eq(false)
                    expect(player_2[:remaining_skips_with_attack_cards]).to eq(0)
                  else
                    expect(player_2[:attack_turn]).to eq(true)
                    expect(player_2[:remaining_skips_with_attack_cards]).to eq(2)
                  end
                end
              )
          end
        end
      end
    end
  end

  describe 'defend' do
    describe 'success' do
      let(:password) { 'any password' }
      let(:current_user) { ::ApplicationCable::User.new }
      let(:current_user_nickname) { 'a good player 1 nickname' }
      let(:second_player) { ::ApplicationCable::User.new }
      let(:second_player_nickname) { 'player 2 nickname here' }

      let!(:match) do
        Matches[password] = ::Match::Model.new(
          player_1_id: current_user.id,
          player_1_nickname: current_user_nickname,
          observers: [::GameChannel]
        )

        Matches[password].join(player_id: second_player.id, player_nickname: second_player_nickname)
        Matches[password].start
        
        Matches[password]
      end

      let(:is_player_1_attack_turn) { match.state(current_user.id)[:player_1][:attack_turn] }
      let(:attacking_player_id) { is_player_1_attack_turn ? current_user.id : second_player.id }
      let(:defending_player_id) { is_player_1_attack_turn ? second_player.id : current_user.id }

      let!(:atacking_player_cards) { [weapons[0], weapons[0], weapons[3], armors[0], health_potions[0]] }
      let!(:cards_used_in_attack_turn) { [weapons[0], weapons[0], weapons[3], armors[0]].pluck(:id) }
      let!(:valid_used_attack_cards) { [weapons[0], weapons[3]].map { |c| ::Card::Serializer.call(c) } }
      
      let!(:defending_player_cards) { [armors[0], armors[0], armors[3], weapons[0], health_potions[0]] }
      let!(:cards_used_in_defense_turn) { [armors[0], armors[0], armors[3], weapons[0], health_potions[0]].pluck(:id) }
      let!(:valid_used_cards) { [armors[0], armors[3]].map { |c| ::Card::Serializer.call(c) } }

      before do
        match
          .instance_variable_get(is_player_1_attack_turn ? :@player_1 : :@player_2)
          .instance_variable_set(:@cards, atacking_player_cards)
        
        match
          .instance_variable_get(is_player_1_attack_turn ? :@player_2 : :@player_1)
          .instance_variable_set(:@cards, defending_player_cards)

        match.attack(player_id: attacking_player_id, cards: cards_used_in_attack_turn)

        stub_connection(current_user: defending_player_id == current_user.id ? current_user : second_player)
        subscribe password:
      end

      let(:turn_attack) { 12 }
      let(:turn_defense) { 7 }
      let(:turn_damage) { 5 }
      let(:health_after_defense) { ::Player::INITIAL_HEALTH - turn_damage }

      subject(:defend) { perform :defend, cards: cards_used_in_defense_turn }

      context 'when match finishes' do
        before do
          Matches[password]
            .instance_variable_get(defending_player_id == current_user.id ? :@player_1 : :@player_2)
            .instance_variable_set(:@health, 1)
        end

        it 'notifies that match finished' do
          winner = defending_player_id == current_user.id ? second_player_nickname : current_user_nickname

          expect { defend }
            .to have_broadcasted_to("notifications_#{current_user.id}")
            .with(method: 'match_finished', data: { winner: winner })
            .and have_broadcasted_to("notifications_#{second_player.id}")
            .with(method: 'match_finished', data: { winner: winner })
        end
      end

      context 'when player defends with no cards' do
        subject(:defend) { perform :defend, cards: [[weapons[0]], nil, []].sample }
        
        it 'both players ends with 5 cards' do
          defend

          expect(match.state(current_user.id)[:player_1][:cards].length).to eq(5)
          expect(match.state(second_player.id)[:player_2][:cards].length).to eq(5)
        end
      end

      it 'returns match state to player one' do
        expect { defend }
          .to have_broadcasted_to("notifications_#{current_user.id}")
          .with(
            lambda do |payload|
              expect(payload[:method]).to eq('end_defense_turn')

              player_1 = payload[:data][:player_1]

              expect(::Card::Record.pluck(:id)).to include(*player_1[:cards].pluck(:id))

              expect(player_1[:cards])
                .to match_array([weapons[0], armors[0], health_potions[0]].map { |c| ::Card::Serializer.call(c) })

              expect(player_1[:id]).to eq(current_user.id)
              expect(player_1[:nickname]).to eq(current_user_nickname)
              expect(player_1[:attack_turn]).to eq(false)

              if defending_player_id == current_user.id
                expect(player_1[:health]).to eq(health_after_defense)
                expect(player_1[:using_cards]).to match_array(valid_used_cards)
                expect(player_1[:defense_turn]).to eq(true)
              else
                expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_1[:using_cards]).to match_array(valid_used_attack_cards)
                expect(player_1[:defense_turn]).to eq(false)
              end

              player_2 = payload[:data][:player_2]

              expect(player_2[:cards]).to eq(nil)
              expect(player_2[:id]).to eq(second_player.id)
              expect(player_2[:nickname]).to eq(second_player_nickname)
              expect(player_2[:attack_turn]).to eq(false)

              if defending_player_id == second_player.id
                expect(player_2[:health]).to eq(health_after_defense)
                expect(player_2[:using_cards]).to match_array(valid_used_cards)
                expect(player_2[:defense_turn]).to eq(true)
              else
                expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_2[:using_cards]).to match_array(valid_used_attack_cards)
                expect(player_2[:defense_turn]).to eq(false)
              end
            end
          )

        expect(match.state(current_user.id)[:player_1][:cards].length).to eq(5)
        expect(match.state(second_player.id)[:player_2][:cards].length).to eq(5)
      end

      it 'returns match state to player two' do
        expect { defend }
          .to have_broadcasted_to("notifications_#{second_player.id}")
          .with(
            lambda do |payload|
              expect(payload[:method]).to eq('end_defense_turn')

              player_1 = payload[:data][:player_1]

              expect(player_1[:cards]).to eq(nil)
              expect(player_1[:id]).to eq(current_user.id)
              expect(player_1[:nickname]).to eq(current_user_nickname)
              expect(player_1[:attack_turn]).to eq(false)

              if defending_player_id == current_user.id
                expect(player_1[:health]).to eq(health_after_defense)
                expect(player_1[:using_cards]).to match_array(valid_used_cards)
                expect(player_1[:defense_turn]).to eq(true)
              else
                expect(player_1[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_1[:using_cards]).to match_array(valid_used_attack_cards)
                expect(player_1[:defense_turn]).to eq(false)
              end

              player_2 = payload[:data][:player_2]

              expect(::Card::Record.pluck(:id)).to include(*player_2[:cards].pluck(:id))

              expect(player_2[:cards])
                .to match_array([weapons[0], armors[0], health_potions[0]].map { |c| ::Card::Serializer.call(c) })

              expect(player_2[:id]).to eq(second_player.id)
              expect(player_2[:nickname]).to eq(second_player_nickname)
              expect(player_2[:attack_turn]).to eq(false)

              if defending_player_id == second_player.id
                expect(player_2[:health]).to eq(health_after_defense)
                expect(player_2[:using_cards]).to match_array(valid_used_cards)
                expect(player_2[:defense_turn]).to eq(true)
              else
                expect(player_2[:health]).to eq(::Player::INITIAL_HEALTH)
                expect(player_2[:using_cards]).to match_array(valid_used_attack_cards)
                expect(player_2[:defense_turn]).to eq(false)
              end
            end
          )

        expect(match.state(current_user.id)[:player_1][:cards].length).to eq(5)
        expect(match.state(second_player.id)[:player_2][:cards].length).to eq(5)
      end
    end
  end
end
