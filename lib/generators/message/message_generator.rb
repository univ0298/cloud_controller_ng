class MessageGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  argument :model, type: :string

  def generate_message_file
    template "message_template.rb.erb", "app/messages/#{file_name}.rb"
  end

  def generate_message_spec_file
    template "message_spec_template.rb.erb", "spec/unit/messages/#{file_name}_spec.rb"
  end
end
