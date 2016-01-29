describe 'Sending a test message' do
  let(:user) { users(:logan) }

  context 'GCM' do
    it 'sends the message via GCM' do
      stub_request(:post, %r{gcm/send}).to_return body: '{}', status: 200
      Pushable::TestMessage.new.send_to user
      expect(WebMock).to have_requested(:post, 'https://android.googleapis.com/gcm/send').with body: {
        data: {},
        alert: 'This is a test push from Pushable',
        registration_ids: ['logan123']
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
      Pushable::TestMessage.new.send_to user
      expect(apns_service).to have_received(:deliver).once.with(apns_notification, ['logan123'])
      expect(APNS::Notification).to have_received(:new).once.with(
        'alert' => 'This is a test push from Pushable',
        'badge' => 1,
        'sound' => 'default',
        'other' => {}
      )
    end
  end
end
