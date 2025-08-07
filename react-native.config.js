module.exports = {
  dependencies: {
    'react-native-ftp-client': {
      platforms: {
        android: {
          sourceDir: '../node_modules/react-native-ftp-client/android/',
          packageImportPath: 'import com.reactlibrary.ftpclient.RNFtpClientPackage;',
          packageClassName: 'RNFtpClientPackage'
        },
        ios: {
          podspecPath: '../node_modules/react-native-ftp-client/react-native-ftp-client.podspec'
        }
      }
    }
  }
};
