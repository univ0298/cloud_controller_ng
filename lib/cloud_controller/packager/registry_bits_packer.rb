require 'package_image_uploader/client'

module CloudController
  module Packager
    class RegistryBitsPacker
      def send_package_to_blobstore(package_guid, uploaded_package_zip, _)
        registry = VCAP::CloudController::Config.config.get(:packages, :image_registry, :base_path)
        client = PackageImageUploader::Client.new(
          VCAP::CloudController::Config.config.get(:package_image_uploader, :host),
          VCAP::CloudController::Config.config.get(:package_image_uploader, :port),
        )

        response = client.post_package(package_guid, uploaded_package_zip, registry)
        { sha1: nil, sha256: response['hash']['hex'] }
      end

      private

      def tmp_dir
        @tmp_dir ||= VCAP::CloudController::Config.config.get(:directories, :tmpdir)
      end

      def global_app_bits_cache
        @global_app_bits_cache ||= CloudController::DependencyLocator.instance.global_app_bits_cache
      end

      def max_package_size
        @max_package_size ||= VCAP::CloudController::Config.config.get(:packages, :max_package_size)
      end
    end
  end
end
