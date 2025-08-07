# react-native-ftp-client

A ftp client library for react native
Thanks for [react-native-ftp](https://github.com/ne0z/react-native-ftp).
Get inspired from it, but almost rewrite every corner.

## Features

1. Support four operations
    * list ftp dir.  
    * upload file to ftp.  
    * download file from ftp.
    * remove file or dir from ftp.  

2. NO session, which means treating each operation as a session.  
   Therefore, it is easier to use for javascript client even introduce some overhead on login and logout.  

## Installation

```bash
npm install react-native-ftp-client
```

### React Native 0.60 and above

Since React Native 0.60, the CLI autolink feature automatically handles the linking process. Run the following commands:

```bash
cd ios && pod install
```

### React Native 0.59 and below

Run the following commands to link the library:

```bash
npx react-native link react-native-ftp-client
```

### Manual linking (if needed)

#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-ftp-client` and add `RNFtpClient.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNFtpClient.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Android

1. Open up `android/app/src/main/java/[...]/MainApplication.java`
  - Add `import com.reactlibrary.ftpclient.RNFtpClientPackage;` to the imports at the top of the file
  - Add `new RNFtpClientPackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':react-native-ftp-client'
  	project(':react-native-ftp-client').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-ftp-client/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':react-native-ftp-client')
  	```

## Limit

the download operation depends on the ftp server support size cmd

## Example
```javascript
const downloadFileFrom = async (ftpHost, remote_file_path) => {
    FTP.setup({
      ip_address: ftpHost,
      port: 21,
      username: 'anonymous',
      password: 'guest',
    }); //Setup host

    const localPath = 'local file path';

    try {
      let currentToken = '';
      const subscription = FTP.addProgressListener(({token, percentage}) => {
        if (percentage === 0) {
            //record token
            currentToken = token;
        }
        if (token !== currentToken) {
            //ignore
        } else {
            //show percentage. it is a integer
            if (percentage >= 100) {
                //finish download
            }
        }
      });
      await FTP.downloadFile(localPath, remote_file_path);
      //continue after download finish
    } catch (error) {
        if(error.message === FTP.ERROR_MESSAGE_CANCELLED){
            //the download is cancelled
        }
        //other error
    }
  };
  ```