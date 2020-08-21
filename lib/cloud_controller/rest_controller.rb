require 'controllers/base/base_controller'
require 'controllers/base/model_controller'
require 'framework/rest_controller'

module VCAP::CloudController
  module RestController
    include VCAP::Framework::RestController
  end
  def self.controller_from_model(model)
    controller_from_model_name(model.class.name)
  end

  def self.controller_from_model_name(model_name)
    controller_from_name(model_name.to_s.split('::').last)
  end

  def self.controller_from_name(name)
    controller_from_name_mapping.fetch(name) do
      VCAP::CloudController.const_get("#{name.to_s.pluralize.camelize}Controller")
    end
  end

  def self.controller_from_relationship(relationship)
    return nil unless relationship.try(:association_controller).present?

    VCAP::CloudController.const_get(relationship.association_controller)
  end

  def self.controller_from_name_mapping
    @controller_from_name_mapping ||= {}
  end

  def self.set_controller_for_model_name(model_name:, controller:)
    controller_from_name_mapping[model_name] = controller
  end
end
