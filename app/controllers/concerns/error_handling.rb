module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
    rescue_from ActiveRecord::RecordNotUnique, with: :render_record_not_unique
    rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
    rescue_from ActionDispatch::Http::Parameters::ParseError, with: :render_parse_error
    rescue_from InvalidParameter, with: :render_invalid_parameter
    rescue_from Auth::InvalidCredentials, with: :render_invalid_credentials
    rescue_from Auth::InvalidRefreshToken, with: :render_invalid_refresh_token
    # Expired and Invalid stay siblings. Handlers match in reverse order of declaration, so making
    # Expired a subclass of Invalid would route every expiry to render_invalid_token.
    rescue_from AccessToken::Expired, with: :render_token_expired
    rescue_from AccessToken::Invalid, with: :render_invalid_token
  end

  private
    def render_error(status, code, message, details: [])
      render json: { error: { code: code, message: message, details: details } }, status: status
    end

    def render_not_found(error)
      render_error :not_found, "not_found", "#{error.model || "Record"} not found"
    end

    def render_record_invalid(error)
      errors = error.record.errors
      details = errors.map { |e| { field: e.attribute, message: e.message } }
      render_error :unprocessable_content, "validation_failed", errors.full_messages.to_sentence, details: details
    end

    # The adapter error names a constraint, not a field, so there is nothing to put in details.
    def render_record_not_unique(_error)
      render_error :unprocessable_content, "validation_failed", "A record with these values already exists"
    end

    def render_parameter_missing(error)
      render_error :bad_request, "parameter_missing", "#{error.param} is required",
                   details: [ { field: error.param, message: "is required" } ]
    end

    def render_parse_error(_error)
      render_error :bad_request, "malformed_body", "Request body could not be parsed"
    end

    def render_invalid_parameter(error)
      render_error :unprocessable_content, "validation_failed", error.message,
                   details: [ { field: error.field, message: error.detail } ]
    end

    def render_invalid_credentials(_error)
      render_error :unauthorized, "invalid_credentials", "Email or password is incorrect"
    end

    def render_invalid_refresh_token(_error)
      render_error :unauthorized, "invalid_refresh_token", "Refresh token is expired or has already been used"
    end

    def render_token_expired(_error)
      render_error :unauthorized, "token_expired", "Access token has expired"
    end

    def render_invalid_token(_error)
      render_error :unauthorized, "invalid_token", "Access token is missing or invalid"
    end
end
