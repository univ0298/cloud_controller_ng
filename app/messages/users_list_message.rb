require 'messages/metadata_list_message'

module VCAP::CloudController
  class UsersListMessage < MetadataListMessage
    register_allowed_keys [:guids, :usernames, :origins]

    validates_with NoAdditionalParamsValidator
    validates :guids, allow_nil: true, array: true
    validates :usernames, allow_nil: true, array: true
    validates :origins, allow_nil: true, array: true

    validates_with OriginMustBePairedWithUserName


    def self.from_params(params)
      super(params, %w(guids usernames origins))
    end

    class OriginMustBePairedWithUserName < ActiveModel::Validator
      def validate(record)
        if record.requested?(:origins)
          if !record.requested?(:usernames)
            record.errors[:base] << "Unknown field(s): '#{record.extra_keys.join("', '")}'"
          else
          end
        end
      end
    end
    
  end
