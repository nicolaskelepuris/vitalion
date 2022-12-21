# frozen_string_literal: true

# rubocop:disable Style/MutableConstant
Matches = {}
# rubocop:enable Style/MutableConstant

module Matching
  def find_match(password)
    Matches[password]
  end

  def create_match(password, match)
    Matches[password] = match
  end
end
