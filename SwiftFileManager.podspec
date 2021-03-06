Pod::Spec.new do |s|
  s.name             = "SwiftFileManager"
  s.version          = "0.5.4"
  s.summary          = "A handy Swift extension that makes life easier when dealing with files on iOS / Mac OS X."
  s.homepage         = "https://github.com/BellAppLab/SwiftFileManager"
  s.license          = 'MIT'
  s.author           = { "Bell App Lab" => "apps@bellapplab.com" }
  s.source           = { :git => "https://github.com/BellAppLab/SwiftFileManager.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/BellAppLab'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'

  s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'Backgroundable'
  s.dependency 'BLLogger'
  s.dependency 'Stringer'
  s.deprecated = true
end
