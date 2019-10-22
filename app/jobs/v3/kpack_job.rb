module VCAP::CloudController
  module Jobs
    module V3
      class KpackJob
        def initialize(build_guid)
          @build_guid = build_guid

        end

        def perform
          image_json = {
            apiVersion: 'build.pivotal.io/v1alpha1',
            kind: 'Image',
            metadata: {
              name: 'catnip',
              namespace: 'default'
            },
            spec: {
              tag: 'gcr.io/cf-capi-arya/catnip-image-hackday',
              serviceAccount: 'kpack-service-account-hackday'
            },
            builder: {
              name: 'sample-builder',
              kind: 'ClusterBuilder'
            },
            source: {
              blob: {
                url: 'https://storage.googleapis.com/capi-rey-packages/98/57/9857165d-f784-42be-9ae7-052971eab188'
              }
            }
          }

          image_spec = image_json.to_json

          # generate yaml
          # kubectl apply -f image-spec.yaml
          # use https://github.com/abonas/kubeclient#watch-events-for-a-particular-object to know when done
          # create job
        end

      end
    end
  end
end
