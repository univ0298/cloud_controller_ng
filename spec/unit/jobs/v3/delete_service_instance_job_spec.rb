require 'db_spec_helper'
require 'support/shared_examples/jobs/delayed_job'
require 'jobs/v3/delete_service_instance_job'
require 'cloud_controller/errors/api_error'
require 'cloud_controller/user_audit_info'
require 'services/service_brokers/v2/http_response'
require 'actions/v3/service_instance_delete'

module VCAP::CloudController
  module V3
    RSpec.describe DeleteServiceInstanceJob do
      it_behaves_like 'delayed job', described_class

      subject(:job) { described_class.new(service_instance.guid, user_audit_info) }

      let(:service_offering) { Service.make }
      let(:service_plan) { ServicePlan.make(service: service_offering) }
      let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: User.make.guid, user_email: 'foo@example.com') }

      describe '#perform' do
        let(:delete_response) { { finished: false, operation: 'test-operation' } }
        let(:poll_response) { { finished: false } }
        let(:action) do
          double(VCAP::CloudController::V3::ServiceInstanceDelete, {
            delete: delete_response,
            poll: poll_response
          })
        end

        before do
          allow(VCAP::CloudController::V3::ServiceInstanceDelete).to receive(:new).and_return(action)
        end

        context 'first time' do
          context 'synchronous response' do
            let(:delete_response) { { finished: true } }

            it 'calls delete and then finishes' do
              job.perform

              expect(action).to have_received(:delete).with(service_instance)
              expect(job.finished).to be_truthy
            end

            it 'does not poll' do
              job.perform

              expect(action).not_to have_received(:poll)
            end
          end

          context 'asynchronous response' do
            let(:delete_response) { { finished: false } }

            context 'computes the maximum duration' do
              before do
                TestConfig.override({
                  broker_client_max_async_poll_duration_minutes: 90009
                })
                job.perform
              end

              it 'sets to the default value' do
                expect(job.maximum_duration_seconds).to eq(90009.minutes)
              end

              context 'when the plan defines a duration' do
                let(:maximum_polling_duration) { 7465 }
                let(:service_plan) { ServicePlan.make(service: service_offering, maximum_polling_duration: maximum_polling_duration) }

                it 'sets to the plan value' do
                  expect(job.maximum_duration_seconds).to eq(7465)
                end
              end
            end

            it 'calls delete and then poll' do
              job.perform

              expect(action).to have_received(:delete).with(service_instance)
              expect(action).to have_received(:poll).with(service_instance)
              expect(job.finished).to be_falsey
            end
          end
        end

        context 'subsequent times' do
          before do
            service_instance.save_with_new_operation({}, {
              type: 'delete',
              state: 'in progress',
              broker_provided_operation: Sham.guid,
            })
          end

          it 'only calls poll' do
            job.perform

            expect(action).not_to have_received(:delete)
            expect(action).to have_received(:poll).with(service_instance)
            expect(job.finished).to be_falsey
          end

          context 'poll indicates binding complete' do
            let(:poll_response) { { finished: true } }

            it 'finishes the job' do
              job.perform

              expect(job.finished).to be_truthy
            end
          end

          context 'the maximum duration' do
            it 'recomputes the value' do
              job.maximum_duration_seconds = 90009
              TestConfig.override({ broker_client_max_async_poll_duration_minutes: 8088 })
              job.perform
              expect(job.maximum_duration_seconds).to eq(8088.minutes)
            end

            context 'when the plan value changes between calls' do
              before do
                job.maximum_duration_seconds = 90009
                service_plan.update(maximum_polling_duration: 5000)
                job.perform
              end

              it 'sets to the new plan value' do
                expect(job.maximum_duration_seconds).to eq(5000)
              end
            end
          end
        end

        context 'retry interval' do
          def test_retry_after(value, expected)
            allow(action).to receive(:poll).and_return({ finished: false, retry_after: value })
            job.perform
            expect(job.polling_interval_seconds).to eq(expected)
          end

          it 'updates the polling interval' do
            test_retry_after(10, 60) # below default
            test_retry_after(65, 65)
            test_retry_after(1.hour, 1.hour)
            test_retry_after(25.hours, 24.hours) # above limit
          end
        end

        context 'service instance not found' do
          before do
            service_instance.destroy
          end

          it 'finishes the job' do
            job.perform

            expect(job.finished).to be_truthy
          end
        end

        context 'delete fails' do
          it 're-raises API errors' do
            allow(action).to receive(:delete).and_raise(
              CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name))

            expect { job.perform }.to raise_error(
              CloudController::Errors::ApiError,
              "An operation for service instance #{service_instance.name} is in progress.",
            )
          end

          it 'wraps other errors' do
            allow(action).to receive(:delete).and_raise(StandardError, 'bad thing')

            expect { job.perform }.to raise_error(
              CloudController::Errors::ApiError,
              'delete could not be completed: bad thing',
            )
          end
        end

        context 'poll fails' do
          it 're-raises API errors' do
            allow(action).to receive(:poll).and_raise(
              CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name))

            expect { job.perform }.to raise_error(
              CloudController::Errors::ApiError,
              "An operation for service instance #{service_instance.name} is in progress.",
            )
          end

          it 'wraps other errors' do
            allow(action).to receive(:poll).and_raise(StandardError, 'bad thing')

            expect { job.perform }.to raise_error(
              CloudController::Errors::ApiError,
              'delete could not be completed: bad thing',
            )
          end
        end
      end

      describe 'handle timeout' do
      end

      # describe '#perform' do
      #   context 'when the client succeeds' do
      #     let(:r) do
      #       VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: '204', body: 'all good')
      #     end
      #
      #     before do
      #       allow(client).to receive(:deprovision).and_return(r)
      #
      #       subject.perform
      #     end
      #
      #     it 'the pollable job state is set to polling' do
      #       expect(subject.pollable_job_state).to eq(PollableJobModel::POLLING_STATE)
      #     end
      #   end
      #
      #   context 'when there is a create operation in progress' do
      #     before do
      #       service_instance.save_with_new_operation({}, { type: 'create', state: 'in progress', description: 'barz' })
      #     end
      #
      #     it 'attempts to delete anyways' do
      #       expect { subject.perform }.to_not raise_error
      #     end
      #   end
      #
      #   context 'when the client raises a ServiceBrokerBadResponse' do
      #     let(:r) do
      #       VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: '204', body: 'unexpected failure!')
      #     end
      #
      #     let(:err) do
      #       VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse.new(nil, :delete, r)
      #     end
      #
      #     before do
      #       allow(client).to receive(:deprovision).and_raise(err)
      #     end
      #
      #     it 'restarts the job, as to perform orphan mitigation' do
      #       subject.perform
      #
      #       expect(subject.instance_variable_get(:@attempts)).to eq(1)
      #       expect(subject.instance_variable_get(:@first_time)).to eq(true)
      #     end
      #
      #     it 'the pollable job state is set to processing' do
      #       subject.perform
      #
      #       expect(subject.pollable_job_state).to eq(PollableJobModel::PROCESSING_STATE)
      #     end
      #
      #     it 'does not modify the service instance operation' do
      #       service_instance.save_with_new_operation(
      #         {},
      #         { type: 'create', state: 'done' }
      #       )
      #
      #       subject.perform
      #
      #       service_instance.reload
      #
      #       expect(service_instance.last_operation.type).to eq('create')
      #       expect(service_instance.last_operation.state).to eq('done')
      #     end
      #
      #     it 'logs a message' do
      #       subject.perform
      #
      #       expect(logger).to have_received(:info).with(/Triggering orphan mitigation/)
      #     end
      #
      #     it 'fails after too many retries' do
      #       number_of_successes = VCAP::CloudController::V3::ServiceInstanceAsyncJob::MAX_RETRIES - 1
      #       number_of_successes.times do
      #         subject.perform
      #       end
      #
      #       expect { subject.perform }.to raise_error(CloudController::Errors::ApiError)
      #     end
      #   end
      #
      #   context 'when the client raises an API Error' do
      #     before do
      #       allow(client).to receive(:deprovision).and_raise(err)
      #       service_instance.save_with_new_operation({}, {
      #         type: 'create',
      #         state: 'in progress',
      #         broker_provided_operation: 'some create operation'
      #       })
      #     end
      #
      #     let(:err) do
      #       CloudController::Errors::ApiError.new_from_details('NotFound')
      #     end
      #
      #     it 'fails the job and update the service instance last operation' do
      #       expect { subject.perform }.to raise_error(CloudController::Errors::ApiError, /Unknown request/)
      #       expect(subject.instance_variable_get(:@attempts)).to eq(0)
      #
      #       service_instance.reload
      #
      #       expect(service_instance.last_operation.type).to eq('delete')
      #       expect(service_instance.last_operation.state).to eq('failed')
      #     end
      #
      #     context 'and the error name is AsyncServiceInstanceOperationInProgress' do
      #       let(:err) do
      #         CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', 'some name')
      #       end
      #
      #       it 'fails the job but do not update the service instance last operation' do
      #         expect { subject.perform }.to raise_error(CloudController::Errors::ApiError, /create in progress/)
      #         expect(subject.instance_variable_get(:@attempts)).to eq(0)
      #
      #         service_instance.reload
      #
      #         expect(service_instance.last_operation.type).to eq('create')
      #         expect(service_instance.last_operation.state).to eq('in progress')
      #         expect(service_instance.last_operation.broker_provided_operation).to eq('some create operation')
      #       end
      #     end
      #   end
      #
      #   context 'when the client raises a general error' do
      #     let(:err) { StandardError.new('random error') }
      #
      #     before do
      #       allow(client).to receive(:deprovision).and_raise(err)
      #     end
      #
      #     it 'fails the job' do
      #       expect { subject.perform }.to raise_error(err)
      #       expect(subject.instance_variable_get(:@attempts)).to eq(0)
      #
      #       service_instance.reload
      #
      #       expect(service_instance.last_operation.type).to eq('delete')
      #       expect(service_instance.last_operation.state).to eq('failed')
      #     end
      #   end
      # end

      describe '#operation' do
        it 'returns "deprovision"' do
          expect(job.operation).to eq(:deprovision)
        end
      end

      describe '#operation_type' do
        it 'returns "delete"' do
          expect(job.operation_type).to eq('delete')
        end
      end

      describe '#resource_type' do
        it 'returns "service_instances"' do
          expect(job.resource_type).to eq('service_instance')
        end
      end

      describe '#resource_guid' do
        it 'returns the service instance guid' do
          expect(job.resource_guid).to eq(service_instance.guid)
        end
      end

      describe '#display_name' do
        it 'returns the display name' do
          expect(job.display_name).to eq('service_instance.delete')
        end
      end

      # describe '#send_broker_request' do
      #   let(:client) { double('BrokerClient', deprovision: 'some response') }
      #
      #   it 'sends a deprovision request' do
      #     subject.send_broker_request(client)
      #
      #     expect(client).to have_received(:deprovision).with(
      #       service_instance,
      #       accepts_incomplete: true,
      #     )
      #   end
      #
      #   it 'returns the client response' do
      #     response = subject.send_broker_request(client)
      #     expect(response).to eq('some response')
      #   end
      #
      #   it 'sets the @request_failed to false' do
      #     subject.send_broker_request(client)
      #     expect(subject.instance_variable_get(:@request_failed)).to eq(false)
      #   end
      #
      #   context 'when the client raises a ServiceBrokerBadResponse' do
      #     it 'raises a DeprovisionBadResponse error' do
      #       r = VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: '204', body: 'unexpected failure!')
      #       err = VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse.new(nil, :delete, r)
      #       allow(client).to receive(:deprovision).and_raise(err)
      #
      #       expect { subject.send_broker_request(client) }.to raise_error(DeprovisionBadResponse, /unexpected failure!/)
      #     end
      #   end
      #
      #   context 'when the client raises a AsyncServiceInstanceOperationInProgress' do
      #     it 'raises a DeprovisionBadResponse error' do
      #       err = CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', 'some instance name')
      #       allow(client).to receive(:deprovision).and_raise(err)
      #
      #       expect { subject.send_broker_request(client) }.to raise_error(OperationCancelled, /rejected the request/)
      #     end
      #   end
      #
      #   context 'when the client raises an unknown error' do
      #     it 'raises the error' do
      #       allow(client).to receive(:deprovision).and_raise(RuntimeError.new('oh boy'))
      #       expect { subject.send_broker_request(client) }.to raise_error(RuntimeError, 'oh boy')
      #     end
      #   end
      # end
      #
      # describe '#gone!' do
      #   it 'finishes the job' do
      #     job = DeleteServiceInstanceJob.new(service_instance.guid, user_audit_info)
      #     expect { job.gone! }.not_to raise_error
      #     expect(job.finished).to eq(true)
      #   end
      # end
      #
      # describe '#operation_succeeded' do
      #   let(:deprovision_response) do
      #     {
      #       last_operation: { state: 'succeeded', type: 'delete' }
      #     }
      #   end
      #
      #   it 'deletes the service instance from the db' do
      #     expect(ManagedServiceInstance.first(guid: service_instance.guid)).not_to be_nil
      #     subject.perform
      #     expect(ManagedServiceInstance.first(guid: service_instance.guid)).to be_nil
      #   end
      #
      #   it 'logs an audit event with null request body' do
      #     subject.perform
      #
      #     last_audit_event = Event.find(type: 'audit.service_instance.delete')
      #     expect(last_audit_event.metadata).to have_key('request')
      #
      #     request = last_audit_event.metadata['request']
      #     expect(request).to eql(nil)
      #   end
      # end
      #
      # describe '#restart_on_failure?' do
      #   it 'returns true' do
      #     expect(subject.restart_on_failure?).to eq(true)
      #   end
      # end
    end
  end
end
