require 'spec_helper'
require 'messages/roles_list_message'

module VCAP::CloudController
  RSpec.describe RolesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5
        }
      end

      it 'returns the correct RolesListMessage' do
        message = RolesListMessage.from_params(params)

        expect(message).to be_a(RolesListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
      end

      it 'converts requested keys to symbols' do
        message = RolesListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
      end

      describe 'fields' do
        it 'accepts an empty set' do
          message = RolesListMessage.from_params({})
          expect(message).to be_valid
        end

        it 'does not accept any other params' do
          message = RolesListMessage.from_params({ foobar: 'pants' })

          expect(message).to be_invalid
          expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
        end
      end
    end
  end
end
