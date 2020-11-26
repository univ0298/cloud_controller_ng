require 'spec_helper'
require 'actions/v3/service_instance_delete'

module VCAP
  module CloudController
    RSpec.describe V3::ServiceInstanceDelete do
      describe '#delete' do
        subject(:action) { described_class.new(event_repository) }

        let(:event_repository) do
          dbl = double(Repositories::ServiceEventRepository::WithUserActor)
          allow(dbl).to receive(:record_user_provided_service_instance_event)
          allow(dbl).to receive(:user_audit_info)
          dbl
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

          it 'deletes it from the database' do
            subject.delete(service_instance)

            expect {
              service_instance.reload
            }.to raise_error(Sequel::Error, 'Record not found')
            expect(VCAP::CloudController::ServiceInstanceLabelModel.where(service_instance: service_instance)).to be_empty
            expect(VCAP::CloudController::ServiceInstanceAnnotationModel.where(service_instance: service_instance)).to be_empty
          end

          it 'creates an audit event' do
            subject.delete(service_instance)

            expect(event_repository).
              to have_received(:record_user_provided_service_instance_event).
              with(:delete, instance_of(UserProvidedServiceInstance))
          end

          it 'returns true' do
            expect(subject.delete(service_instance)).to be_truthy
          end
        end

        context 'managed service instances' do
          let!(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }

          it 'returns false' do
            expect(subject.delete(service_instance)).to be_falsey
          end
        end

        describe 'recursion' do
          before do
            allow_any_instance_of(Repositories::ServiceGenericBindingEventRepository).to receive(:record_delete)
          end

          context 'when there are associated service bindings' do
            let!(:service_instance) { UserProvidedServiceInstance.make(route_service_url: 'https://bar.com') }
            let!(:binding) { ServiceBinding.make(service_instance: service_instance) }

            before do
              subject.delete(service_instance)
            end

            it 'deletes the service bindings too' do
              expect(ServiceBinding.all).to be_empty
              expect(ServiceInstance.all).to be_empty
            end
          end

          # TODO: technically a user-provided instance cannot have a key
          context 'when there are associated service keys' do
            let!(:service_instance) { UserProvidedServiceInstance.make(route_service_url: 'https://bar.com') }
            let!(:key) { VCAP::CloudController::ServiceKey.make(service_instance: service_instance) }

            before do
              subject.delete(service_instance)
            end

            it 'deletes the service keys too' do
              expect(ServiceBinding.all).to be_empty
              expect(ServiceInstance.all).to be_empty
            end
          end

          context 'when there are associated route bindings' do
            let!(:service_instance) { UserProvidedServiceInstance.make(route_service_url: 'https://bar.com') }
            let!(:route_binding) do
              VCAP::CloudController::RouteBinding.make(
                service_instance: service_instance,
                route: VCAP::CloudController::Route.make(space: service_instance.space)
              )
            end

            before do
              subject.delete(service_instance)
            end

            it 'deletes the route bindings too' do
              expect(RouteBinding.all).to be_empty
              expect(ServiceInstance.all).to be_empty
            end
          end

          context 'when the service instance is shared' do
            let(:space) { VCAP::CloudController::Space.make }
            let(:other_space) { VCAP::CloudController::Space.make }
            let!(:service_instance) {
              # TODO: technically a user-provided instance cannot be shared, but the test is simpler this way
              si = VCAP::CloudController::UserProvidedServiceInstance.make(space: space)
              si.shared_space_ids = [other_space.id]
              si
            }

            before do
              allow(Repositories::ServiceInstanceShareEventRepository).to receive(:record_unshare_event)

              subject.delete(service_instance)
            end

            it 'deletes the service instance' do
              expect(ServiceInstance.all).to be_empty
            end
          end
        end
      end
    end
  end
end
