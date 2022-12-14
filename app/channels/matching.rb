module Matching
  Matches = {}

  def find_match(password)
    Matches[params[:password]]
  end

  def create_match(password, match)
    Matches[params[:password]] = match
  end
end