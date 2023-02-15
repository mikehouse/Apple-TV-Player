platform :tvos, '14.0'

target 'Apple-TV-Player' do

  use_frameworks!

  pod 'TVVLCKit'
  pod "Reusable"

end

target 'Channels' do

  use_frameworks!

  pod 'GZIP'

end

target 'ChannelsTests' do

  use_frameworks!

  pod 'GZIP'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['TVOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end