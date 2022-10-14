module Transfertpro
  class Error < StandardError
    attr_reader :http_response
    def initialize(message, http_response = nil)
      super(message)
      @http_response = http_response
    end
  end
end
