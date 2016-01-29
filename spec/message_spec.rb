describe 'Messaging' do
  let(:user) { users(:logan) }

  before do
    # Mercurius::Testing::Base.reset
  end

  context 'GCM' do
    it 'sends the message via GCM' do
      stub_request(:post, %r[gcm/send]).to_return body: '{}', status: 200
      TestMessage.new.send_to user
      expect(WebMock).to have_requested(:post, 'https://android.googleapis.com/gcm/send').with body: {
        data: {
          data: 123
        },
        alert: 'This is an alert',
        registration_ids: ['logan123']
      }
    end

    it 'sends the message via GCM and ActiveRecord::Relation' do
      stub_request(:post, %r[gcm/send]).to_return body: '{}', status: 200
      TestMessage.new.send_to User.all
      expect(WebMock).to have_requested(:post, 'https://android.googleapis.com/gcm/send').with body: {
        data: {
          data: 123
        },
        alert: 'This is an alert',
        registration_ids: ['logan123', 'john123']
      }
    end
  end

  context 'APNS' do
    let(:apns_service) { instance_double(APNS::Service, deliver: nil) }
    let(:apns_notification) { instance_double(APNS::Notification) }

    before do
      Pushable::Device.all.each { |d| d.update platform: 'ios' }
      allow(APNS::Service).to receive(:new) { apns_service }
      allow(APNS::Notification).to receive(:new) { apns_notification }
    end

    it 'sends the message via APNS' do
      TestMessage.new.send_to user
      expect(apns_service).to have_received(:deliver).once.with(apns_notification, ['logan123'])
      expect(APNS::Notification).to have_received(:new).once.with(
        'alert' => 'This is an alert',
        'badge' => 2,
        'sound' => 'test',
        'other' => {
          'data' => 123
        }
      )
    end

    it 'sends the message via APNS and ActiveRecord::Relation' do
      TestMessage.new.send_to User.all
      expect(apns_service).to have_received(:deliver).once.with(apns_notification, ['logan123', 'john123'])
      expect(APNS::Notification).to have_received(:new).once.with(
        'alert' => 'This is an alert',
        'badge' => 2,
        'sound' => 'test',
        'other' => {
          'data' => 123
        }
      )
    end

    it 'sends the message via APNS with content-available set to 1' do
      message = TestMessage.new
      allow(message).to receive(:content_available?) { true }
      message.send_to user
      expect(apns_service).to have_received(:deliver).once.with(apns_notification, ['logan123'])
      expect(APNS::Notification).to have_received(:new).once.with(
        'alert' => 'This is an alert',
        'badge' => 2,
        'sound' => 'test',
        'other' => {
          'data' => 123
        },
        'content_available' => 1
      )
    end
  end

  context 'Both' do
    let(:apns_service) { instance_double(APNS::Service, deliver: nil) }
    let(:apns_notification) { instance_double(APNS::Notification) }

    before do
      allow(APNS::Service).to receive(:new) { apns_service }
      allow(APNS::Notification).to receive(:new) { apns_notification }
      stub_request(:post, %r[gcm/send]).to_return body: '{}', status: 200
    end

    it 'sends one message to APNS and another to GCM' do
      pushable_devices(:logan).update! platform: 'ios'
      pushable_devices(:john).update! platform: 'android'
      TestMessage.new.send_to User.all
      expect(APNS::Notification).to have_received(:new).once.with(
        'alert' => 'This is an alert',
        'badge' => 2,
        'sound' => 'test',
        'other' => {
          'data' => 123
        }
      )
      expect(WebMock).to have_requested(:post, 'https://android.googleapis.com/gcm/send').with body: {
        data: {
          data: 123
        },
        alert: 'This is an alert',
        registration_ids: ['john123']
      }
    end
  end
end
