describe FastlaneCore::AnalyticsSession do
  let(:oauth_app_name) { 'fastlane-tests' }
  let(:p_hash) { 'some.phash.value' }
  let(:session_id) { 's0m3s3ss10n1D' }
  let(:timestamp_millis) { 1_507_142_046 }
  let(:fixture_dirname) do
    dirname = File.expand_path(File.dirname(__FILE__))
    File.join(dirname, './fixtures/')
  end

  before(:each) do
    # This value needs to be set or our event fixtures will not match
    allow(FastlaneCore::Helper).to receive(:ci?).and_return(false)
  end

  context 'single action execution' do
    let(:session) { FastlaneCore::AnalyticsSession.new }
    let(:action_name) { 'some_action' }

    context 'action launch' do
      let(:launch_context) do
        FastlaneCore::ActionLaunchContext.new(
          action_name: action_name,
          p_hash: p_hash,
          platform: 'ios'
        )
      end

      let(:fixture_data) do
        JSON.parse(File.read(File.join(fixture_dirname, '/launched.json')))
      end

      it "adds all events to the session's events array" do
        expect(SecureRandom).to receive(:uuid).and_return(session_id)
        allow(Time).to receive(:now).and_return(timestamp_millis)

        # Stub out calls related to the execution environment
        session.is_fastfile = true
        allow(session).to receive(:oauth_app_name).and_return(oauth_app_name)
        expect(session).to receive(:fastlane_version).and_return('2.5.0')
        expect(session).to receive(:ruby_version).and_return('2.4.0')
        expect(session).to receive(:operating_system_version).and_return('10.12')
        expect(session).to receive(:ide_version).and_return('Xcode 9')

        session.action_launched(launch_context: launch_context)

        parsed_events = JSON.parse(session.events.to_json)
        parsed_events.zip(fixture_data).each do |parsed, fixture|
          expect(parsed).to eq(fixture)
        end
      end
    end

    context 'action completion' do
      let(:completion_context) do
        FastlaneCore::ActionCompletionContext.new(
          p_hash: p_hash,
          status: FastlaneCore::ActionCompletionStatus::SUCCESS,
          action_name: action_name
        )
      end

      let(:fixture_data) do
        event = JSON.parse(File.read(File.join(fixture_dirname, '/completed_success.json')))
        event["action"]["detail"] = action_name
        event
      end

      it 'appends a completion event to the events array' do
        expect(SecureRandom).to receive(:uuid).and_return(session_id)
        expect(Time).to receive(:now).and_return(timestamp_millis)

        expect(session).to receive(:oauth_app_name).and_return(oauth_app_name)

        session.action_completed(completion_context: completion_context)
        expect(JSON.parse(session.events.last.to_json)).to eq(fixture_data)
      end
    end
  end

  context 'two action execution' do
    let(:session) { FastlaneCore::AnalyticsSession.new }
    let(:action_1_name) { 'some_action1' }
    let(:action_2_name) { 'some_action2' }

    context 'action launch' do
      let(:action_1_launch_context) do
        FastlaneCore::ActionLaunchContext.new(
          action_name: action_1_name,
          p_hash: p_hash,
          platform: 'ios'
        )
      end
      let(:action_1_completion_context) do
        FastlaneCore::ActionCompletionContext.new(
          p_hash: p_hash,
          status: FastlaneCore::ActionCompletionStatus::SUCCESS,
          action_name: action_1_name
        )
      end
      let(:action_2_launch_context) do
        FastlaneCore::ActionLaunchContext.new(
          action_name: action_2_name,
          p_hash: p_hash,
          platform: 'ios'
        )
      end
      let(:action_2_completion_context) do
        FastlaneCore::ActionCompletionContext.new(
          p_hash: p_hash,
          status: FastlaneCore::ActionCompletionStatus::SUCCESS,
          action_name: action_2_name
        )
      end
      let(:fixture_data_action_1_launched) do
        events = JSON.parse(File.read(File.join(fixture_dirname, '/launched.json')))
        events.each { |event| event["action"]["detail"] = action_1_name }
        events
      end
      let(:fixture_data_action_2_launched) do
        events = JSON.parse(File.read(File.join(fixture_dirname, '/launched.json')))
        events.each { |event| event["action"]["detail"] = action_2_name }
        events
      end
      let(:fixture_data_action_1_completed) do
        event = JSON.parse(File.read(File.join(fixture_dirname, '/completed_success.json')))
        event["action"]["detail"] = action_1_name
        event
      end
      let(:fixture_data_action_2_completed) do
        event = JSON.parse(File.read(File.join(fixture_dirname, '/completed_success.json')))
        event["action"]["detail"] = action_2_name
        event
      end

      it "adds all events to the session's events array" do
        expect(SecureRandom).to receive(:uuid).and_return(session_id)
        allow(Time).to receive(:now).and_return(timestamp_millis)

        # Stub out calls related to the execution environment
        session.is_fastfile = true
        allow(session).to receive(:oauth_app_name).and_return(oauth_app_name)
        expect(session).to receive(:fastlane_version).and_return('2.5.0').twice
        expect(session).to receive(:ruby_version).and_return('2.4.0').twice
        expect(session).to receive(:operating_system_version).and_return('10.12').twice
        expect(session).to receive(:ide_version).and_return('Xcode 9').twice

        session.action_launched(launch_context: action_1_launch_context)
        session.action_completed(completion_context: action_1_completion_context)
        session.action_launched(launch_context: action_2_launch_context)
        session.action_completed(completion_context: action_2_completion_context)

        expected_final_array = fixture_data_action_1_launched + [fixture_data_action_1_completed] + fixture_data_action_2_launched + [fixture_data_action_2_completed]
        parsed_events = JSON.parse(session.events.to_json)

        parsed_events.zip(expected_final_array).each do |parsed, fixture|
          expect(parsed).to eq(fixture)
        end
      end
    end
  end

  context 'mock Fastfile executions' do
    before(:each) do
      FastlaneCore.reset_session
    end

    let(:fixture_data) do
      events = JSON.parse(File.read(File.join(fixture_dirname, '/launched.json')))
      events.each { |event| event["action"]["detail"] = 'lane_switch' }
      events
    end

    let(:guesser) { FastlaneCore::AppIdentifierGuesser.new }

    it "properly tracks the lane switches", :tagged do
      allow(UI).to receive(:success)
      allow(UI).to receive(:header)
      allow(UI).to receive(:message)

      allow(Time).to receive(:now).and_return(timestamp_millis)

      expect(FastlaneCore::AppIdentifierGuesser).to receive(:new).and_return(guesser)
      allow(guesser).to receive(:p_hash).and_return(p_hash)
      allow(guesser).to receive(:platform).and_return('ios')

      FastlaneCore.session.is_fastfile = true
      allow(FastlaneCore.session).to receive(:oauth_app_name).and_return(oauth_app_name)
      expect(FastlaneCore.session).to receive(:fastlane_version).and_return('2.5.0')
      expect(FastlaneCore.session).to receive(:ruby_version).and_return('2.4.0')
      expect(FastlaneCore.session).to receive(:operating_system_version).and_return('10.12')
      expect(FastlaneCore.session).to receive(:ide_version).and_return('Xcode 9')
      expect(FastlaneCore.session).to receive(:session_id).and_return(session_id)

      ff = Fastlane::FastFile.new('./fastlane/spec/fixtures/fastfiles/SwitcherFastfile')
      ff.runner.execute(:lane1, :ios)

      parsed_events = JSON.parse(FastlaneCore.session.events.to_json)
      parsed_events.zip(fixture_data).each do |parsed, fixture|
        expect(parsed).to eq(fixture)
      end
    end

    # it 'records more than one action from a Fastfile' do
    #   ff = Fastlane::LaneManager.cruise_lane('ios', 'beta')
    #   expect(ff.collector.launches).to eq({ default_platform: 1, frameit: 1, team_id: 2 })
    # end
  end
end

# here are a bunch of tests we should also have
# these were scattered around, but I think we should put them in one place

# it "Successfully collected all actions" do
#   ff = Fastlane::LaneManager.cruise_lane('ios', 'beta')
#   expect(ff.collector.launches).to eq({ default_platform: 1, frameit: 1, team_id: 2 })
# end

#       let(:collector) { FastlaneCore::ToolCollector.new }

# it "keeps track of what tools get invoked" do
#   collector.did_launch_action(:scan)

#   expect(collector.launches[:scan]).to eq(1)
#   expect(collector.launches[:gym]).to eq(0)
# end

# it "tracks which tool raises an error" do
#   collector.did_raise_error(:scan)

#   expect(collector.error).to eq(:scan)
#   expect(collector.crash).to be(false)
# end

# it "tracks which tool crashes" do
#   collector.did_crash(:scan)

#   expect(collector.error).to eq(:scan)
#   expect(collector.crash).to be(true)
# end

# it "does not post the collected data if the opt-out ENV var is set" do
#   with_env_values('FASTLANE_OPT_OUT_USAGE' => '1') do
#     collector.did_launch_action(:scan)
#     expect(collector.finalize_session).to eq(false)
#   end
# end

# describe "#name_to_track" do
#   it "returns the original name when it's a built-in action" do
#     expect(collector.name_to_track(:fastlane)).to eq(:fastlane)
#   end

#   it "returns nil when it's an external action" do
#     expect(collector).to receive(:is_official?).and_return(false)
#     expect(collector.name_to_track(:fastlane)).to eq(nil)
#   end
# end

# it "posts the collected data with a crash when finished" do
#   collector.did_launch_action(:gym)
#   collector.did_launch_action(:scan)
#   collector.did_crash(:scan)

#   analytic_event_body = collector.create_analytic_event_body
#   analytics = JSON.parse(analytic_event_body)['analytics']

#   expect(analytics.size).to eq(4)
#   expect(analytics.find_all { |a| a['primary_target']['detail'] == '1' && a['actor']['detail'] == 'scan' }.size).to eq(1)
#   expect(analytics.find_all { |a| a['primary_target']['detail'] == '1' && a['actor']['detail'] == 'gym' }.size).to eq(1)
#   expect(analytics.find_all { |a| a['secondary_target']['detail'] == Fastlane::VERSION && a['actor']['detail'] == 'scan' }.size).to eq(2)
#   expect(analytics.find_all { |a| a['secondary_target']['detail'] == Fastlane::VERSION && a['actor']['detail'] == 'gym' }.size).to eq(2)
#   expect(analytics.find_all { |a| a['primary_target']['detail'] == 'crash' && a['actor']['detail'] == 'scan' }.size).to eq(1)
#   expect(analytics.find_all { |a| a['primary_target']['detail'] == 'success' && a['actor']['detail'] == 'gym' }.size).to eq(1)
# end

# it "posts the collected data with an error when finished" do
#   collector.did_launch_action(:gym)
#   collector.did_launch_action(:scan)
#   collector.did_raise_error(:scan)

#   analytic_event_body = collector.create_analytic_event_body
#   analytics = JSON.parse(analytic_event_body)['analytics']

#   expect(analytics.size).to eq(4)
#   expect(analytics.find_all { |a| a['primary_target']['detail'] == '1' && a['actor']['detail'] == 'scan' }.size).to eq(1)
#   expect(analytics.find_all { |a| a['primary_target']['detail'] == '1' && a['actor']['detail'] == 'gym' }.size).to eq(1)
#   expect(analytics.find_all { |a| a['secondary_target']['detail'] == Fastlane::VERSION && a['actor']['detail'] == 'scan' }.size).to eq(2)
#   expect(analytics.find_all { |a| a['secondary_target']['detail'] == Fastlane::VERSION && a['actor']['detail'] == 'gym' }.size).to eq(2)
#   expect(analytics.find_all { |a| a['primary_target']['detail'] == 'error' && a['actor']['detail'] == 'scan' }.size).to eq(1)
#   expect(analytics.find_all { |a| a['primary_target']['detail'] == 'success' && a['actor']['detail'] == 'gym' }.size).to eq(1)
# end

# it "posts the web onboarding data with a success when finished" do
#   with_env_values('GENERATED_FASTFILE_ID' => 'fastfile_id') do
#     collector.did_launch_action(:fastlane)

#     analytic_event_body = collector.create_analytic_event_body
#     analytics = JSON.parse(analytic_event_body)['analytics']

#     expect(analytics.size).to eq(3)
#     expect(analytics.find_all { |a| a['primary_target']['detail'] == '1' && a['actor']['detail'] == 'fastlane' }.size).to eq(1)
#     expect(analytics.find_all { |a| a['event_source']['product'] != 'fastlane_web_onboarding' && a['secondary_target']['detail'] == Fastlane::VERSION && a['actor']['detail'] == 'fastlane' }.size).to eq(2)
#     expect(analytics.find_all { |a| a['primary_target']['detail'] == 'success' && a['actor']['detail'] == 'fastlane' }.size).to eq(1)
#     expect(analytics.find_all { |a| a['action']['name'] == 'fastfile_executed' && a['actor']['detail'] == 'fastfile_id' && a['primary_target']['detail'] == 'success' }.size).to eq(1)
#   end
# end

# it "posts the web onboarding data with an crash when finished" do
#   with_env_values('GENERATED_FASTFILE_ID' => 'fastfile_id') do
#     collector.did_launch_action(:fastlane)
#     collector.did_crash(:gym)

#     analytic_event_body = collector.create_analytic_event_body
#     analytics = JSON.parse(analytic_event_body)['analytics']

#     expect(analytics.size).to eq(3)
#     expect(analytics.find_all { |a| a['primary_target']['detail'] == '1' && a['actor']['detail'] == 'fastlane' }.size).to eq(1)
#     expect(analytics.find_all { |a| a['event_source']['product'] != 'fastlane_web_onboarding' && a['secondary_target']['detail'] == Fastlane::VERSION && a['actor']['detail'] == 'fastlane' }.size).to eq(2)
#     expect(analytics.find_all { |a| a['action']['name'] == 'fastfile_executed' && a['primary_target']['detail'] == 'crash' && a['actor']['detail'] == 'fastfile_id' }.size).to eq(1)
#   end
# end

# it "posts the web onboarding data with an error when finished" do
#   with_env_values('GENERATED_FASTFILE_ID' => 'fastfile_id') do
#     collector.did_launch_action(:fastlane)
#     collector.did_raise_error(:gym)

#     analytic_event_body = collector.create_analytic_event_body
#     analytics = JSON.parse(analytic_event_body)['analytics']

#     expect(analytics.size).to eq(3)
#     expect(analytics.find_all { |a| a['primary_target']['detail'] == '1' && a['actor']['detail'] == 'fastlane' }.size).to eq(1)
#     expect(analytics.find_all { |a| a['event_source']['product'] != 'fastlane_web_onboarding' && a['secondary_target']['detail'] == Fastlane::VERSION && a['actor']['detail'] == 'fastlane' }.size).to eq(2)
#     expect(analytics.find_all { |a| a['action']['name'] == 'fastfile_executed' && a['primary_target']['detail'] == 'error' && a['actor']['detail'] == 'fastfile_id' }.size).to eq(1)
#   end
# end

#   let(:mock_tool_collector) { FastlaneCore::AnalyticsSession.new }

#   before(:each) do
#     allow(Commander::Runner).to receive(:instance).and_return(Commander::Runner.new)
#     expect(FastlaneCore::AnalyticsSession).to receive(:new).and_return(mock_tool_collector)
#   end

#   it "calls the tool collector lifecycle methods for a successful run" do
#     expect(mock_tool_collector).to receive(:did_launch_action).with("tool_name").and_call_original
#     expect(mock_tool_collector).to receive(:did_finish).and_call_original

#     CommandsGenerator.new.run
#   end

#   it "calls the tool collector lifecycle methods for a crash" do
#     expect(mock_tool_collector).to receive(:did_launch_action).with("tool_name").and_call_original
#     expect(mock_tool_collector).to receive(:did_crash).with("tool_name").and_call_original

#     expect do
#       CommandsGenerator.new(raise_error: StandardError).run
#     end.to raise_error(StandardError)
#   end

#   it "calls the tool collector lifecycle methods for a user error" do
#     expect(mock_tool_collector).to receive(:did_launch_action).with("tool_name").and_call_original
#     expect(mock_tool_collector).to receive(:did_raise_error).with("tool_name").and_call_original

#     stdout, stderr = capture_stds do
#       expect do
#         CommandsGenerator.new(raise_error: FastlaneCore::Interface::FastlaneError).run
#       end.to raise_error(SystemExit)
#     end
#     expect(stderr).to eq("\n[!] FastlaneCore::Interface::FastlaneError".red + "\n")
#   end

#   it "calls the tool collector lifecycle methods for a test failure" do
#     expect(mock_tool_collector).to receive(:did_launch_action).with("tool_name").and_call_original
#     # Notice how we don't expect `:did_raise_error` to be called here
#     # TestFailures don't count as failures/crashes

#     stdout, stderr = capture_stds do
#       expect do
#         CommandsGenerator.new(raise_error: FastlaneCore::Interface::FastlaneTestFailure).run
#       end.to raise_error(SystemExit)
#     end
#     expect(stderr).to eq("\n[!] FastlaneCore::Interface::FastlaneTestFailure".red + "\n")
#   end

# describe Fastlane::ActionCollector do
#   it "properly tracks the actions" do
#     ENV.delete("FASTLANE_OPT_OUT_USAGE")

#     ff = nil
#     begin
#       ff = Fastlane::FastFile.new.parse("lane :test do
#         add_git_tag(build_number: 0)
#         add_git_tag(build_number: 1)
#       end")
#     rescue
#     end

#     result = ff.runner.execute(:test)

#     expect(ff.collector.launches).to eq({
#       add_git_tag: 2
#     })
#   end

#   it "doesn't track unofficial actions" do
#     ENV.delete("FASTLANE_OPT_OUT_USAGE")

#     Fastlane::Actions.load_external_actions("./fastlane/spec/fixtures/actions") # load custom actions

#     ff = nil
#     begin
#       ff = Fastlane::FastFile.new.parse("lane :test do
#         add_git_tag(build_number: 1)
#         example_action
#       end")
#     rescue
#     end

#     result = ff.runner.execute(:test)

#     expect(ff.collector.launches).to eq({
#       add_git_tag: 1
#     })
#   end
# end