# frozen_string_literal: true

class GameChannel < ApplicationCable::Channel
  include Broadcasting
  include Matching

  def subscribed
    reject unless match.players_ids.include?(current_user)

    stream_from private_broadcasting
    stream_from match_broadcasting(params[:password])
  end

  def start_round
    send_match_state(match, 'start_round')
  end

  def attack(data)
    match.attack(player_id: current_user, cards: data[:cards])
  rescue StandardError => e
    private_broadcast({ method: 'attack_turn', error: e.message })
  end

  def defend(data)
    match.defend(player_id: current_user, cards: data[:cards])
  rescue StandardError => e
    private_broadcast({ method: 'defense_turn', error: e.message })
  end

  def self.end_attack_turn(match)
    send_match_state(match, 'end_attack_turn')
  end

  def self.end_defense_turn(match)
    send_match_state(match, 'end_defense_turn')
  end

  def self.end_round(match)
    send_match_state(match, 'start_round')
  end

  private

  def match
    find_match(params[:password])
  end

  def send_match_state(match, method)
    match.players_ids.each do |id|
      private_broadcast_to(id, { method:, data: match.state(id) })
    end
  end
end
