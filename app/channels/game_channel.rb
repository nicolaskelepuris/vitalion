# frozen_string_literal: true

class GameChannel < ApplicationCable::Channel
  include Matching

  def subscribed
    reject unless match.players_ids.include?(current_user)

    stream_from Broadcasting.private_broadcasting(current_user)
    stream_from Broadcasting.match_broadcasting(params[:password])
  end

  def start_round
    self.class.send_match_state(match, 'start_round')
  end

  def attack(data)
    match.attack(player_id: current_user, cards: data['cards'])
  rescue StandardError => e
    puts "AOOOOOOOOOOOOOOOBA #{e.message}"
    Broadcasting.private_broadcast_to(current_user, { method: 'attack_turn', error: e.message })
  end

  def defend(data)
    match.defend(player_id: current_user, cards: data['cards'])
  rescue StandardError => e
    Broadcasting.private_broadcast_to(current_user, { method: 'defense_turn', error: e.message })
  end

  def self.end_attack_turn(match)
    self.send_match_state(match, 'end_attack_turn')
  end

  def self.end_defense_turn(match)
    self.send_match_state(match, 'end_defense_turn')
  end

  def self.end_round(match)
    self.send_match_state(match, 'start_round')
  end

  def self.send_match_state(match, method)
    match.players_ids.each do |id|
      Broadcasting.private_broadcast_to(id, { method:, data: match.state(id) })
    end
  end

  private

  def match
    find_match(params[:password])
  end
end
