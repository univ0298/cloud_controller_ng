module VCAP::CloudController
  class OrganizationQuotasUpdate
    class Error < ::StandardError
    end

    # org and message?
    def update(quota, message)
      quota.db.transaction do
        quota.name = message.name if message.requested(:name)

      end
    end
  end
end
