# frozen_string_literal: true

module RequestHelpers
  def json
    @json ||= JSON.parse(response.body)
  rescue StandardError
    response.body
  end
end
