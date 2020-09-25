require 'spec_helper'
require 'rails_helper'

RSpec.describe RolesController, type: :controller do # , isolation: :truncation
  describe '#index' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:space1) { VCAP::CloudController::Space.make(organization: organization1) }
    let(:space2) { VCAP::CloudController::Space.make(organization: organization1) }
    let(:space3) { VCAP::CloudController::Space.make(organization: organization2) }
    let(:organization1) { VCAP::CloudController::Organization.make }
    let(:organization2) { VCAP::CloudController::Organization.make }
    let(:organization3) { VCAP::CloudController::Organization.make }
    let(:all_spaces) { [space, space1, space2, space3] }
    let(:user_spaces) { [space, space1, space2] }

    before do
      TestConfig.override({
        db: {
          log_level: 'debug',
      }
        # logging.level: 'debug2'
      })
      allow_user_read_access_for(user, spaces: user_spaces)
      start_time = Time.now
      n.times do |i|
        VCAP::CloudController::AppModel.make(space: all_spaces.sample, guid: "app-guid-#{i}")
      end
      end_time = Time.now
      puts "creation time: #{(end_time - start_time) * 1.0}"
    end

    context 'for 1000 apps' do
      let(:n) { 1000 }
      it 'uses the app and pagination as query parameters' do
        runs = 5

        search_time = 0
        runs.times do |i|
          app_guid_num = rand(n)

          start_time = Time.now
          get :index, params: { app_guids: "app-guid-#{app_guid_num}", page: 1, per_page: 10, states: 'AWAITING_UPLOAD' }
          end_time = Time.now

          search_time += (end_time - start_time) * 1.0
        end
        avg_time = (search_time * 1.0) / runs

        expect(avg_time).to be <= 0.2
      end
    end
  end

  context 'for 10000 apps' do
    let(:n) { 10000 }
    it 'uses the app and pagination as query parameters' do
      runs = 5

      search_time = 0
      runs.times do |i|
        app_guid_num = rand(n)

        start_time = Time.now
        get :index, params: { app_guids: "app-guid-#{app_guid_num}", page: 1, per_page: 10, states: 'AWAITING_UPLOAD' }
        end_time = Time.now

        search_time += (end_time - start_time) * 1.0
      end
      avg_time = (search_time * 1.0) / runs

      expect(avg_time).to be <= 0.2
    end
  end
end
