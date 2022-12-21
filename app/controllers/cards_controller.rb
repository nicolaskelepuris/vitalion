# frozen_string_literal: true

class CardsController < ApplicationController
  def index
    render json: { data: ::Card::List.call.map { |c| c.as_json(only: %i[id name attack defense]) } }
  end
end
