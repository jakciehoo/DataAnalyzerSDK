#
# Be sure to run `pod lib lint YRKDataAnalyzer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'YRKDataAnalyzer'
  s.version          = '1.0.0'
  s.summary          = 'A short description of YRKDataAnalyzer.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/胡江华/YRKDataAnalyzer'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '胡江华' => 'hujianghua@yiruikecorp.com' }
  s.source           = { :git => 'http://10.35.33.29:9999/hujianghua/YRKDataAnalyzer_iOS.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'YRKDataAnalyzer/Classes/**/*'
  
  # s.resource_bundles = {
  #   'YRKDataAnalyzer' => ['YRKDataAnalyzer/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'OpenUDID', '1.0.0'
  s.dependency 'JQFMDB', '1.1.6'
  s.dependency  'YYModel', '1.0.4'
end
