# frozen_string_literal: true

class CardsController < ApplicationController
  def index
    render json: { data: ::Card::List.call.map { |c| ::Card::Serializer.call(c) } }
  end
end
