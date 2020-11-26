require 'jobs/v3/delete_service_instance_job'

module VCAP::CloudController
  module V3
    class ServiceInstanceDelete
      def initialize(event_repo)
        @service_event_repository = event_repo
      end

      def delete(service_instance)
        lock = DeleterLock.new(service_instance)

        case service_instance
        when ManagedServiceInstance
          return false
        when UserProvidedServiceInstance
          lock.lock!
          synchronous_destroy(service_instance, lock)
          return true
        end
      end

      class AssociationNotEmptyError < StandardError; end

      class InstanceSharedError < StandardError; end

      private

      def synchronous_destroy(service_instance, lock)
        quick_delete_dependent_resources(service_instance)

        lock.unlock_and_destroy!
        service_event_repository.record_user_provided_service_instance_event(:delete, service_instance)
        nil
      end

      def quick_delete_dependent_resources(service_instance)
        quick_delete_route_bindings(service_instance)
        quick_delete_app_bindings(service_instance)
        quick_delete_service_keys(service_instance)
        quick_delete_service_shares(service_instance)
      end

      def quick_delete_route_bindings(service_instance)
        RouteBinding.where(service_instance: service_instance, route: service_instance.routes).each do |route_binding|
          ServiceRouteBindingDelete.new(service_event_repository.user_audit_info).quick_delete(route_binding)
        end
      end

      def quick_delete_app_bindings(service_instance)
        service_instance.service_bindings.each do |service_binding|
          ServiceCredentialBindingDelete.new(service_event_repository.user_audit_info).quick_delete(service_binding)
        end
      end

      def quick_delete_service_keys(service_instance)
        service_instance.service_keys.each do |service_binding|
          ServiceCredentialBindingDelete.new(service_event_repository.user_audit_info).quick_delete(service_binding)
        end
      end

      def quick_delete_service_shares(service_instance)
        service_instance.shared_spaces.each do |shared_space|
          ServiceInstanceUnshare.new.unshare(service_instance, shared_space, service_event_repository.user_audit_info)
        end
      end

      attr_reader :service_event_repository
    end
  end
end
