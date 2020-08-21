module VCAP::Framework
  module RestController
  end
end

require 'framework/rest_controller/common_params'
require 'framework/rest_controller/controller_dsl'
require 'framework/rest_controller/secure_eager_loader'
require 'framework/rest_controller/object_renderer'
require 'framework/rest_controller/order_applicator'
require 'framework/rest_controller/preloaded_object_serializer'
require 'framework/rest_controller/paginated_collection_renderer'
require 'framework/rest_controller/messages'
