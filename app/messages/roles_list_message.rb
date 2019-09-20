require 'messages/list_message'

module VCAP::CloudController
  class RolesListMessage < ListMessage
    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, [])
    end
  end
end
