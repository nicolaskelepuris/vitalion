class GameChannel < ApplicationCable::Channel
  include Broadcasting
  include Matching

  def subscribed
    private_broadcast({ data: match.player_state(current_user) })
  end

  def receive(data)
    if data[:attack]
      match.attack(player_id: current_user, cards: data[:cards])
    else
      match.defend(player_id: current_user, cards: data[:cards])
    end
  end

  def self.end_turn(match)
    match.players_ids.each do |id|
      private_broadcast_to(id, match.player_state(id))
    end
    
    match_broadcast(params[:password], { data: match.state })
  end

  private

  def match
    @match ||= find_match(params[:password])
  end
end