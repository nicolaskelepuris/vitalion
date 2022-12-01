class CardsController < ApplicationController
  def index
    render json: { data: ::Card::List.call.map { |c| c.as_json(only: [:id, :name, :attack, :defense]) } }
  end
end
