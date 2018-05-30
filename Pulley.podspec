#
# Be sure to run `pod lib lint Pulley.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Pulley'
  s.version          = '2.4.2'
  s.summary          = 'A library to imitate the iOS 10 Maps UI.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
A library to provide a drawer controller that can imitate the drawer UI in iOS 10's Maps app.
                       DESC

  s.homepage         = 'https://github.com/52inc/Pulley'
  s.screenshots     = 'https://camo.githubusercontent.com/ffa1a97f8e152bb25f69970a08aa2e827fe54ce0/687474703a2f2f692e696d6775722e636f6d2f35616b456a69542e676966'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Brendan Lee' => 'brendan@52inc.com' }
  s.source           = { :git => 'https://github.com/52inc/Pulley.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/52_inc'

  s.ios.deployment_target = '9.0'
  s.swift_version = '4.0'

  s.source_files = 'PulleyLib/*.{h,swift}'

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit'

  s.xcconfig = {
    'SWIFT_VERSION' => '4.0'
  }

end
