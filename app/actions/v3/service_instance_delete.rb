require 'jobs/v3/delete_service_instance_job'
require 'actions/services/locks/deleter_lock'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class ServiceInstanceDelete
      class AssociationNotEmptyError < StandardError;
      end

      class InstanceSharedError < StandardError;
      end

      DeleteStatus = Struct.new(:finished, :operation).freeze
      DeleteStarted = ->(operation) { DeleteStatus.new(false, operation) }
      DeleteComplete = DeleteStatus.new(true, nil).freeze

      PollingStatus = Struct.new(:finished, :retry_after).freeze
      PollingFinished = PollingStatus.new(true, nil).freeze
      ContinuePolling = ->(retry_after) { PollingStatus.new(false, retry_after) }


      def initialize(event_repo)
        @service_event_repository = event_repo
      end

      def delete(service_instance)
        lock = DeleterLock.new(service_instance)
        lock.lock!

        result = send_deprovison_to_broker(service_instance)
        if result[:finished]
          lock.unlock_and_destroy!
          record_delete_event(service_instance)
        else
          save_operation_id(service_instance, result[:operation])
          record_start_delete_event(service_instance)
        end

        result
      end

      def delete_checks(service_instance)
        association_not_empty! if service_instance.has_bindings? || service_instance.has_keys? || service_instance.has_routes?
        cannot_delete_shared_instances! if service_instance.shared?
      end


      def poll(service_instance)

      end

      private

      def send_deprovison_to_broker(service_instance)
        client = VCAP::Services::ServiceClientProvider.provide(service_instance)
        result = client.deprovision(service_instance, accepts_incomplete: true)
        return DeleteComplete if result[:last_operation][:state] == 'succeeded'
        DeleteStarted.call(result[:last_operation][:broker_provided_operation])
      end

      def record_delete_event(service_instance)
        case service_instance
        when VCAP::CloudController::ManagedServiceInstance
          service_event_repository.record_service_instance_event(:delete, service_instance)
        when VCAP::CloudController::UserProvidedServiceInstance
          service_event_repository.record_user_provided_service_instance_event(:delete, service_instance)
        end
      end

      def record_start_delete_event(service_instance)
        service_event_repository.record_service_instance_event(:start_delete, service_instance)
      end

      def save_operation_id(service_instance, operation)
        service_instance.save_with_new_operation(
          {},
          {
            type: 'delete',
            state: 'in progress',
            broker_provided_operation: operation
          }
        )
      end

      def association_not_empty!
        raise AssociationNotEmptyError
      end

      def cannot_delete_shared_instances!
        raise InstanceSharedError
      end

      attr_reader :service_event_repository
    end
  end
end
