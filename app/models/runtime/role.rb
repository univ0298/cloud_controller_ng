module VCAP::CloudController
  class Role < Sequel::Model
    many_to_one :user
    many_to_one :space
  end
end
