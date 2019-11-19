require 'spec_helper'
require 'messages/users_list_message'

module VCAP::CloudController
  RSpec.describe UsersListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
          'guids' => 'user1-guid,user2-guid',
          'usernames' => 'user1-name,user2-name',
          'origins' => 'user1-origin,user2-origin',
        }
      end

      it 'returns the correct UsersListMessage' do
        message = UsersListMessage.from_params(params)

        expect(message).to be_a(UsersListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.guids).to eq(%w[user1-guid user2-guid])
        expect(message.usernames).to eq(%w[user1-name user2-name])
        expect(message.origins).to eq(%w[user1-origin user2-origin])
      end

      it 'converts requested keys to symbols' do
        message = UsersListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:guids)).to be_truthy
        expect(message.requested?(:usernames)).to be_truthy
        expect(message.requested?(:origins)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          page: 1,
          per_page: 5,
        }
      end

      it 'excludes the pagination keys' do
        expected_params = []
        expect(UsersListMessage.from_params(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts an empty set' do
        message = UsersListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'accepts a guids param' do
        message = UsersListMessage.from_params({ guids: %w[guid1 guid2] })
        expect(message).to be_valid
        expect(message.guids).to eq(%w[guid1 guid2])
      end

      it 'accepts a usernames param' do
        message = UsersListMessage.from_params({ usernames: %w[username1 username2] })
        expect(message).to be_valid
        expect(message.usernames).to eq(%w[username1 username2])
      end

      it 'accepts an origins param' do
        message = UsersListMessage.from_params({ origins: %w[user1origin user2origin] })
        expect(message).to be_valid
        expect(message.origins).to eq(%w[user1origin user2origin])
      end

      it 'does not accept a non-array guids param' do
        message = UsersListMessage.from_params({ guids: 'not array' })
        expect(message).to be_invalid
        expect(message.errors[:guids]).to include('must be an array')
      end

      it 'does not accept a non-array usernames param' do
        message = UsersListMessage.from_params({ usernames: 'not array' })
        expect(message).to be_invalid
        expect(message.errors[:usernames]).to include('must be an array')
      end

      it 'does not accept a non-array origins param' do
        message = UsersListMessage.from_params({ origins: 'not array' })
        expect(message).to be_invalid
        expect(message.errors[:origins]).to include('must be an array')
      end

      it 'does not accept a field not in this set' do
        message = UsersListMessage.from_params({ foobar: 'pants' })

        expect(message).to be_invalid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end
  end
end
