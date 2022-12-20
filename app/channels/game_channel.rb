class GameChannel < ApplicationCable::Channel
  include Broadcasting
  include Matching

  def subscribed
    stream_from match_broadcasting(params[:password])
    private_broadcast({ data: match.state(current_user) })
  end

  def receive(data)
    if data[:attack]
      match.attack(player_id: current_user, cards: data[:cards])
    else
      match.defend(player_id: current_user, cards: data[:cards])
    end
  rescue StandardError => e
    private_broadcast({ error: e.message })
  end

  def self.end_turn(match)
    match.players_ids.each do |id|
      private_broadcast_to(id, { data: match.state(id) })
    end
  end

  def self.end_attack_or_defense(attack: nil, defense: nil)
    match_broadcast(params[:password], { data: { current_attack: attack, current_defense: defense } })
  end

  private

  def match
    @match ||= find_match(params[:password])
  end
end
