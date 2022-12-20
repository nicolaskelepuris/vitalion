class GameChannel < ApplicationCable::Channel
  include Broadcasting
  include Matching

  def subscribed
    reject unless match.players_ids.include?(current_user)

    stream_from private_broadcasting
    stream_from match_broadcasting(params[:password])
  end

  def match_state
    send_match_state
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

  def self.end_turn(match)
    send_match_state
  end

  def self.end_attack_or_defense(attack: nil, defense: nil)
    match_broadcast(params[:password], { method: 'update_current_play', data: { current_attack: attack, current_defense: defense } })
  end

  private

  def match
    find_match(params[:password])
  end

  def send_match_state
    match.players_ids.each do |id|
      private_broadcast_to(id, { method: 'end_turn', data: match.state(id) })
    end
  end
end
