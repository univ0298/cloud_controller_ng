require 'spec_helper'
require 'jobs/v3/kpack_job'
module VCAP::CloudController
  module Jobs::V3
    RSpec.describe KpackJob do

      describe '#perform' do
        let(:build) { BuildModel.make }

        it 'creates a droplet' do
          expect { KpackJob.new(build.guid).perform }.to change { DropletModel.count }.from(0).to(1)
        end

      end
    end
  end
end
