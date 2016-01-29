module Pushable
  class Message
    MAX_TOKENS_AT_ONCE = 999
    attr_accessor :messenger

    def initialize(messenger = Pushable::Messenger)
      self.messenger = messenger
    end

    def send_to(pushable)
      if pushable.is_a? ActiveRecord::Relation
        enqueue Device.android.owned_by(pushable), format(:android)
        enqueue Device.ios.owned_by(pushable), format(:ios)
      elsif pushable.is_a?(ActiveRecord::Base)
        enqueue pushable.devices.android, format(:android)
        enqueue pushable.devices.ios, format(:ios)
      else
        fail ArgumentError.new('#send_to only accepts an ActiveRecord Relation or ActiveRecord object!')
      end
    end

    def enqueue(devices, payload)
      devices.pluck(:id).each_slice(MAX_TOKENS_AT_ONCE) do |tokens|
        messenger.perform_later tokens, payload.deep_stringify_keys
      end
    end

    def alert
      ''
    end

    def badge
      1
    end

    def sound
      'default'
    end

    def other
      {}
    end

    def content_available?
      false
    end

    private
      def format(platform)
        if platform == :ios
          hash = { alert: alert, badge: badge, sound: sound, other: other }
          hash.merge!(content_available: 1) if content_available?
          hash
        elsif platform == :android
          { alert: alert }.merge(data: other)
        end
      end
  end
end
