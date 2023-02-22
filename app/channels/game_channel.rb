# frozen_string_literal: true

class GameChannel < ApplicationCable::Channel
  include Matching

  def subscribed
    reject unless match.players_ids.include?(current_user.id)

    stream_from Broadcasting.private_broadcasting(current_user.id)
    stream_from Broadcasting.match_broadcasting(params[:password])
  end

  def unsubscribed
    player_match = current_user.match

    if player_match.present?
      player_match.players_ids.select { |id| id != current_user.id }.each do |id|
        Broadcasting.private_broadcast_to(id, { method: 'disconnect_from_channel' })
      end

      delete_match(player_match.password)
    end
  end

  def start_round
    Broadcasting.private_broadcast_to(current_user.id, { method: 'start_round', data: match.state(current_user.id) })
  end

  def attack(data)
    match.attack(player_id: current_user.id, cards: data['cards'])
  rescue StandardError => e
    Broadcasting.private_broadcast_to(current_user.id, { method: 'end_attack_turn', error: e.message })
  end

  def defend(data)
    match.defend(player_id: current_user.id, cards: data['cards'])
  rescue StandardError => e
    Broadcasting.private_broadcast_to(current_user.id, { method: 'end_defense_turn', error: e.message })
  end

  def self.end_attack_turn(match)
    self.send_match_state(match, 'end_attack_turn')
  end

  def self.end_defense_turn(match, was_attack_successful)
    return self.send_match_state(match, 'end_defense_turn', was_attack_successful ? 'attacked' : 'defended') unless match.finished?

    match.players_ids.each do |id|
      winner = match.winner
      is_winner = winner.id == id

      Broadcasting.private_broadcast_to(
        id,
        {
          method: 'match_finished',
          data: { winner: winner.nickname, effect: is_winner ? 'won' : 'loose' }
        }
      )
    end
  end

  def self.end_round(match, reason)
    self.send_match_state(match, 'start_round', reason)
  end

  def self.send_match_state(match, method, effect = nil)
    match.players_ids.each do |id|
      Broadcasting.private_broadcast_to(id, { method:, data: match.state(id).merge(effect: effect) })
    end
  end

  def restart_match
    match.restart
    self.class.send_match_state(match, 'start_round')
  rescue StandardError => e
    Broadcasting.private_broadcast_to(current_user.id, { method: 'start_round', error: e.message })
  end

  private

  def match
    find_match(params[:password])
  end
end
