module SSO
  module Server
    # This is the one interaction point with persisting and querying Passports.
    module Passports
      extend ::SSO::Logging

      def self.generate(owner_id:, ip:, agent:)
        logger.debug { "Generating Passport for user ID #{owner_id.inspect} and IP #{ip.inspect} and Agent #{agent.inspect}" }

        record = backend.create owner_id: owner_id, ip: ip, agent: agent, application_id: 0

        if record.persisted?
          logger.debug { "Successfully generated passport with ID #{record.id}" }
          Operations.success :generation_successful, object: record.id
        else
          Operations.failure :persistence_failed, object: record.errors.to_hash
        end
      end

      def self.register_authorization_grant(passport_id:, token:)
        record       = find_valid_passport(passport_id) { |failure| return failure }
        access_grant = find_valid_access_grant(token)   { |failure| return failure }

        if record.update_attribute :oauth_access_grant_id, access_grant.id
          logger.debug { "Successfully augmented Passport #{record.id} with Authorization Grant ID #{access_grant.id} which is #{access_grant.token}" }
          Operations.success :passport_augmented_with_access_token
        else
          Operations.failure :could_not_augment_passport_with_access_token
        end
      end

      private

      def self.find_valid_passport(id, &block)
        if record = backend.where(revoked_at: nil).find_by_id(id)
          record
        else
          logger.debug { "Could not find valid passport with ID #{id.inspect}" }
          logger.debug { "All I have is #{backend.all.inspect}" }
          yield Operations.failure :passport_not_found if block_given?
          nil
        end
      end

      def self.find_valid_access_grant(token, &block)
        record = ::Doorkeeper::AccessGrant.find_by_token token

        if record && record.valid?
          record
        else
          logger.warn { "Could not find valid Authorization Grant Token #{token.inspect}" }
          yield Operations.failure :access_grant_not_found
          nil
        end
      end

      def self.backend
        ::SSO::Server::Passports::Passport
      end

    end
  end
end
