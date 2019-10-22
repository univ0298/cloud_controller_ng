module VCAP::CloudController
  module Jobs
    module V3
      class KpackJob

        attr_reader :build

        def initialize(build_guid)
          @build = BuildModel.first(guid: build_guid)

        end

        def perform
          # generate yaml
          blobstore = CloudController::DependencyLocator.instance.package_blobstore
          blob = blobstore.blob(build.package.guid)

          image_json = {
            apiVersion: 'build.pivotal.io/v1alpha1',
            kind: 'Image',
            metadata: {
              name: "#{build.guid}",
              namespace: 'default'
            },
            spec: {
              tag: "gcr.io/cf-capi-arya/#{build.guid}",
              serviceAccount: 'kpack-service-account-hackday'
            },
            builder: {
              name: 'sample-builder',
              kind: 'ClusterBuilder'
            },
            source: {
              blob: {
                url: blob.public_download_url
              }
            }
          }

          image_spec = image_json.to_json

          # Kubeclient::Client.new()
          # kubectl apply -f image-spec.yaml
          # use https://github.com/abonas/kubeclient#watch-events-for-a-particular-object to know when done
          # create job
        end

      end
    end
  end
end
