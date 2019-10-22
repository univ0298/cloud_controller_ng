require 'cloud_controller/diego/lifecycles/buildpack_lifecycle'
require 'cloud_controller/diego/lifecycles/docker_lifecycle'
require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class KpackLifecycle
    attr_reader :staging_message

    def initialize(package, staging_message)
      @staging_message = staging_message
      @package = package
    end

    def type
      Lifecycles::KPACK
    end

    def create_lifecycle_data_model(_); end

    def staging_environment_variables
      {}
    end

    def valid?
      true
    end

    def errors
      []
    end

    def stack
      nil
    end
  end
end


module VCAP::CloudController
  class LifecycleProvider
    TYPE_TO_LIFECYCLE_CLASS_MAP = {
      VCAP::CloudController::Lifecycles::BUILDPACK => BuildpackLifecycle,
      VCAP::CloudController::Lifecycles::DOCKER    => DockerLifecycle,
      VCAP::CloudController::Lifecycles::KPACK    => KpackLifecycle
    }.freeze

    def self.provide(package, message)
      type = if message.requested?(:lifecycle)
               message.lifecycle_type
             else
               package.app.lifecycle_type
             end

      TYPE_TO_LIFECYCLE_CLASS_MAP[type].new(package, message)
    end
  end
end
