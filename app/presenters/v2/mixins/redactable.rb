module CloudController
  module Presenters
    module V2
      module Redactable
        def redact_creds_if_necessary(obj)
          access_context = VCAP::CloudController::Security::AccessContext.new

          return obj.credentials if access_context.can?(:read_env, obj)

          { 'redacted_message' => VCAP::CloudController::Presenters::Censorship::PRIVATE_DATA_HIDDEN }
        end
      end
    end
  end
end
