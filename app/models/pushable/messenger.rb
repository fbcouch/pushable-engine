module Pushable
  class Messenger < ActiveJob::Base

    def perform(device_ids, payload)
      send_gcm  Device.android.where(id: device_ids).pluck(:token), payload
      send_apns Device.ios.where(id: device_ids).pluck(:token), payload
    end

    def send_gcm(tokens, payload)
      return unless tokens.any?
      Rails.logger.info "[GCM] Sending to #{tokens.size} tokens..."
      Rails.logger.info "[GCM] Payload: #{payload}"
      service = GCM::Service.new
      notification = GCM::Notification.new(payload)
      responses = service.deliver notification, tokens
      responses.each do |response|
        if error = response.error
          fail Pushable::Error, error
        else
          handle_failed_tokens response.results.failed
          update_devices_to_use_canonical_ids response.results.with_canonical_ids
          Rails.logger.info "[GCM] Response: #{response.status}"
        end
      end
    end

    def send_apns(tokens, payload)
      return unless tokens.any?
      Rails.logger.info "[APNS] Sending to #{tokens.size} tokens..."
      Rails.logger.info "[APNS] Payload: #{payload}"
      Rails.logger.info "[APNS] Payload Bytesize: #{payload.to_s.bytesize}"
      service = APNS::Service.new
      notification = APNS::Notification.new(payload)
      service.deliver notification, tokens
    end

    protected
      def handle_failed_tokens(results)
        results.each do |result|
          device = Pushable::Device.find_by(token: result.token)
          logger.info "#{result.token} failed: #{result.error}"
          if device && invalid_token_error?(result.error)
            logger.info "Invalid token #{device.token} - destroying device #{device.id}."
            device.destroy
          end
        end
      end

      def update_devices_to_use_canonical_ids(results)
        results.each do |result|
          device = Pushable::Device.find_by token: result.token
          next if device.nil?
          if pushable_already_has_token_registered?(device.pushable, result.canonical_id)
            device.destroy
          else
            device.update token: result.canonical_id
          end
        end
      end

      def invalid_token_error?(error)
        error =~ /InvalidRegistration|NotRegistered/
      end

      def pushable_already_has_token_registered?(pushable, token)
        pushable.devices.exists? token: token
      end
  end
end
