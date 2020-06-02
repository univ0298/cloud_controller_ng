require 'spec_helper'
require 'steno/codec_rfc3339'

module VCAP::CloudController
  RSpec.describe StenoConfigurer do
    let(:config_hash) do
      { level: 'debug2', format: { timestamp: 'rfc3339' } }
    end
    subject(:configurer) { StenoConfigurer.new(config_hash) }

    before do
      allow(Steno).to receive(:init)
    end

    describe '.new' do
      it 'accepts a nil' do
        expect { StenoConfigurer.new(nil) }.not_to raise_error
      end
    end

    describe '#configure' do
      before do
        allow(Steno::Config).to receive(:new).and_call_original
        allow(Steno::Config).to receive(:to_config_hash).and_call_original
      end

      it 'calls Steno.init with the desired Steno config' do
        steno_config_hash = {}
        steno_config = double('Steno::Config')
        allow(Steno::Config).to receive(:to_config_hash).and_return(steno_config_hash)
        allow(Steno::Config).to receive(:new).and_return(steno_config)

        configurer.configure

        expect(Steno::Config).to have_received(:to_config_hash).with(config_hash)
        expect(Steno::Config).to have_received(:new).with(steno_config_hash)
        expect(Steno).to have_received(:init).with(steno_config)
      end

      it 'yields the properly configured Steno config hash to a block if provided' do
        block_called = false
        # configurer = StenoConfigurer.new(logging_config = {foo: 'bar'}) Somehow logging_config always gets set to {level: debug2} regardless of how we initialize StenoConfigurer
        configurer.configure do |steno_config_hash|
          block_called = true
          expect(steno_config_hash.fetch(:context)).to be_a Steno::Context::ThreadLocal
          expect(steno_config_hash.fetch(:default_log_level)).to eq :debug2
          expect(steno_config_hash.fetch(:codec)).to be_a(Steno::Codec::JsonRFC3339)
        end

        expect(block_called).to be true
      end
    end
  end
end
