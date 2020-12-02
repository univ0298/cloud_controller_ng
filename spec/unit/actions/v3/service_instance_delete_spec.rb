require 'db_spec_helper'
require 'actions/v3/service_instance_delete'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceInstanceDelete do
      subject(:action) { described_class.new(event_repository) }
      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository::WithUserActor)
        allow(dbl).to receive(:record_user_provided_service_instance_event)
        allow(dbl).to receive(:record_service_instance_event)
        allow(dbl).to receive(:user_audit_info)
        dbl
      end

      describe '#delete' do
        before do
          allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        end

        context 'user-provided service instances' do
          let!(:service_instance) do
            si = VCAP::CloudController::UserProvidedServiceInstance.make(
              name: 'foo',
              credentials: {
                foo: 'bar',
                baz: 'qux'
              },
              syslog_drain_url: 'https://foo.com',
              route_service_url: 'https://bar.com',
              tags: %w(accounting mongodb)
            )
            si.label_ids = [
              VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value'),
              VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
            ]
            si.annotation_ids = [
              VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value').id,
              VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy').id
            ]
            si
          end
          let(:deprovision_response) do
            {
              last_operation: {
                state: 'succeeded',
              }
            }
          end
          let(:client) do
            instance_double(VCAP::Services::ServiceBrokers::UserProvided::Client, {
              deprovision: deprovision_response,
            })
          end

          it 'deletes it from the database' do
            subject.delete(service_instance)

            expect(ServiceInstance.all).to be_empty
          end

          it 'creates an audit event' do
            subject.delete(service_instance)

            expect(event_repository).
              to have_received(:record_user_provided_service_instance_event).
                with(:delete, instance_of(UserProvidedServiceInstance))
          end

          it 'returns finished' do
            result = subject.delete(service_instance)
            expect(result[:finished]).to be_truthy
          end
        end

        context 'managed service instances' do
          let!(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }
          let(:deprovision_response) do
            {
              last_operation: {
                type: 'delete',
                state: 'succeeded',
              }
            }
          end
          let(:client) do
            instance_double(VCAP::Services::ServiceBrokers::V2::Client, {
              deprovision: deprovision_response,
            })
          end
          it 'sends a deprovision to the client' do
            action.delete(service_instance)

            expect(client).to have_received(:deprovision).with(service_instance, accepts_incomplete: true)
          end

          context 'when the client succeeds synchronously' do
            it 'deletes it from the database' do
              subject.delete(service_instance)

              expect(ServiceInstance.all).to be_empty
            end

            it 'creates an audit event' do
              subject.delete(service_instance)

              expect(event_repository).
                to have_received(:record_service_instance_event).
                  with(:delete, instance_of(ManagedServiceInstance))
            end

            it 'returns finished' do
              result = subject.delete(service_instance)
              expect(result[:finished]).to be_truthy
            end
          end

          context 'when the client responds asynchronously' do
            let(:operation) { Sham.guid }
            let(:deprovision_response) do
              {
                last_operation: {
                  type: 'delete',
                  state: 'in progress',
                  broker_provided_operation: operation,
                }
              }
            end

            it 'updates the last operation' do
              subject.delete(service_instance)

              expect(ServiceInstance.first.last_operation.type).to eq('delete')
              expect(ServiceInstance.first.last_operation.state).to eq('in progress')
              expect(ServiceInstance.first.last_operation.broker_provided_operation).to eq(operation)
            end

            it 'creates an audit event' do
              subject.delete(service_instance)

              expect(event_repository).
                to have_received(:record_service_instance_event).
                  with(:start_delete, instance_of(ManagedServiceInstance))
            end

            it 'returns incomplete' do
              result = subject.delete(service_instance)
              expect(result[:finished]).to be_falsey
              expect(result[:operation]).to eq(operation)
            end
          end

          context 'when an update operation is already in progress' do
            before do
              service_instance.save_with_new_operation({}, {type: 'update', state: 'in progress'})
            end

            it 'should raise' do
              expect {
                action.delete(service_instance)
              }.to raise_error(CloudController::Errors::ApiError, "An operation for service instance #{service_instance.name} is in progress.")
            end
          end

          context 'when a create operation is already in progress' do
            before do
              service_instance.save_with_new_operation({}, {type: 'create', state: 'in progress'})
            end

            it 'should delete the service instance' do
              action.delete(service_instance)

              expect(ServiceInstance.all).to be_empty
            end
          end

          context 'when a delete operation is already in progress' do
            before do
              service_instance.save_with_new_operation({}, {type: 'delete', state: 'in progress'})
            end

            it 'should raise' do
              expect {
                action.delete(service_instance)
              }.to raise_error(CloudController::Errors::ApiError, "An operation for service instance #{service_instance.name} is in progress.")
            end
          end
        end
      end

      describe '#delete_checks' do
        describe 'invalid pre-conditions' do
          let!(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(route_service_url: 'https://bar.com') }

          context 'when there are associated service bindings' do
            before do
              VCAP::CloudController::ServiceBinding.make(service_instance: service_instance)
            end

            it 'does not delete the service instance' do
              expect { subject.delete_checks(service_instance) }.to raise_error(V3::ServiceInstanceDelete::AssociationNotEmptyError)
              expect { service_instance.reload }.not_to raise_error
            end
          end

          context 'when there are associated service keys' do
            before do
              VCAP::CloudController::ServiceKey.make(service_instance: service_instance)
            end

            it 'does not delete the service instance' do
              expect { subject.delete_checks(service_instance) }.to raise_error(V3::ServiceInstanceDelete::AssociationNotEmptyError)
              expect { service_instance.reload }.not_to raise_error
            end
          end

          context 'when there are associated route bindings' do
            before do
              VCAP::CloudController::RouteBinding.make(
                service_instance: service_instance,
                route: VCAP::CloudController::Route.make(space: service_instance.space)
              )
            end

            it 'does not delete the service instance' do
              expect { subject.delete_checks(service_instance) }.to raise_error(V3::ServiceInstanceDelete::AssociationNotEmptyError)
              expect { service_instance.reload }.not_to raise_error
            end
          end

          context 'when the service instance is shared' do
            let(:space) { VCAP::CloudController::Space.make }
            let(:other_space) { VCAP::CloudController::Space.make }
            let!(:service_instance) {
              si = VCAP::CloudController::ServiceInstance.make(space: space)
              si.shared_space_ids = [other_space.id]
              si
            }

            it 'does not delete the service instance' do
              expect { subject.delete_checks(service_instance) }.to raise_error(V3::ServiceInstanceDelete::InstanceSharedError)
              expect { service_instance.reload }.not_to raise_error
            end
          end
        end
      end
    end
  end
end
