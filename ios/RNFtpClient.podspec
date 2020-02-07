
Pod::Spec.new do |s|
  s.name         = "RNFtpClient"
  s.version      = "1.0.0"
  s.summary      = "RNFtpClient"
  s.description  = <<-DESC
                  RNFtp
                   DESC
  s.homepage     = "https://github.com"
  s.license      = "MIT"
  s.author             = { "author" => "bruce.li@navico.com" }
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/navico-mobile/react-native-ftp-client", :tag => "master" }
  s.source_files  = "**/*.{c,h,m,mm,cpp}"
  s.requires_arc = true


  s.dependency "React"

end

  
