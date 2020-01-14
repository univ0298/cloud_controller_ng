require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class OrganizationQuotasCreateMessage < OrganizationUpdateMessage

    validates :name,
      presence: true

  end
end
