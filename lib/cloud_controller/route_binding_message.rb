module VCAP::CloudController
  class RouteBindingMessage < VCAP::Framework::RestAPI::Message
    optional :parameters, Hash
  end
end
