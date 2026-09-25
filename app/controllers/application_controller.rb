class ApplicationController < ActionController::API
  private
    def append_info_to_payload(payload)
      super
      payload[:request_id] = request.request_id
    end
end
