require 'jobs/v3/service_instance_async_job'
require 'services/service_brokers/v2/errors/service_broker_bad_response'

module VCAP::CloudController
  module V3
    class DeprovisionBadResponse < StandardError
    end

    class DeleteServiceInstanceJob < VCAP::CloudController::Jobs::ReoccurringJob
      attr_reader :resource_guid

      def initialize(guid, user_audit_info)
        super()
        @resource_guid = guid
        @user_audit_info = user_audit_info
      end

      def perform
        return finish unless service_instance

        self.maximum_duration_seconds = service_instance.service_plan.try(:maximum_polling_duration)

        unless delete_in_progress?
          result = action.delete(service_instance)
          return finish if result[:finished]
        end

        result = action.poll(service_instance)
        return finish if result[:finished]

        self.polling_interval_seconds = result[:retry_after].to_i if result[:retry_after]
      rescue CloudController::Errors::ApiError => err
        raise err
      rescue => err
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', operation_type, err.message)
      end

      # def send_broker_request(client)
      #   deprovision_response = client.deprovision(service_instance, { accepts_incomplete: true })
      #
      #   @request_failed = false
      #
      #   deprovision_response
      # rescue VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse => err
      #   @request_failed = true
      #   raise DeprovisionBadResponse.new(err.message)
      # rescue CloudController::Errors::ApiError => err
      #   raise OperationCancelled.new('The service broker rejected the request') if err.name == 'AsyncServiceInstanceOperationInProgress'
      #
      #   raise err
      # end

      def operation
        :deprovision
      end

      def operation_type
        'delete'
      end

      def resource_type
        'service_instance'
      end

      def display_name
        "#{resource_type}.#{operation_type}"
      end

      # def gone!
      #   finish
      # end

      # def restart_on_failure?
      #   true
      # end

      # def pollable_job_state
      #   return PollableJobModel::PROCESSING_STATE if @request_failed
      #
      #   PollableJobModel::POLLING_STATE
      # end
      #
      # def restart_job(msg)
      #   super
      #   logger.info("could not complete the operation: #{msg}. Triggering orphan mitigation")
      # end

      # def fail!(err)
      #   case err
      #   when DeprovisionBadResponse
      #     trigger_orphan_mitigation(err)
      #   else
      #     super
      #   end
      # end

      private

      attr_reader :user_audit_info

      def service_instance
        ManagedServiceInstance.first(guid: resource_guid)
      end

      def delete_in_progress?
        service_instance.last_operation&.type == 'delete' &&
          service_instance.last_operation&.state == 'in progress'
      end

      def action
        ServiceInstanceDelete.new(Repositories::ServiceEventRepository.new(user_audit_info))
      end

      # def operation_succeeded
      #   ServiceInstance.db.transaction do
      #     service_instance.lock!
      #     service_instance.last_operation&.destroy
      #     service_instance.destroy
      #   end
      # end
      #
      # def trigger_orphan_mitigation(err)
      #   restart_job(err.message)
      # end
    end
  end
end
