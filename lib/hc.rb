require 'honeycomb-beeline'

ENV['HONEYCOMB_DISABLE_AUTOCONFIGURE'] = 'true'
# ENV["HONEYCOMB_DEBUG"] = "true"

module Traceable
  def traced(name)
    original_method = instance_method(name)
    define_method(name) do |*args|
      Honeycomb.start_span(name: name) do
        Honeycomb.add_field('class', original_method.class)
        Honeycomb.add_field('source_location', "#{original_method.source_location[0]}:#{original_method.source_location[1]}")
        Honeycomb.add_field('args', args.inspect)
        original_method.bind(self).call(*args)
      end
    end
  end
end

module Kernel
  extend Traceable

  alias_method :original_require, :require

  # rewrite require
  traced def require(name)
    Honeycomb.add_field('gem_name', name)
    original_require name
  end
end
