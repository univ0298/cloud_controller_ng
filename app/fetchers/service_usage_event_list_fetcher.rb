module VCAP::CloudController
  class ServiceUsageEventListFetcher < BaseListFetcher
    class << self
      def fetch_all(message, dataset)
        filter(message, dataset)
      end

      private

      def filter(message, dataset)
        if message.requested?(:after_guid)
          last_event = dataset.first(guid: message.after_guid[0])
          invalid_after_guid! unless last_event

          dataset = dataset.filter { id > last_event.id }
        end

        if message.requested?(:guids)
          dataset = dataset.where(guid: message.guids)
        end

        super(message, dataset, ServiceUsageEvent)
      end

      def invalid_after_guid!
        raise CloudController::Errors::ApiError.new_from_details(
          'UnprocessableEntity',
          'After guid filter must be a valid service usage event guid.',
        )
      end
    end
  end
end
