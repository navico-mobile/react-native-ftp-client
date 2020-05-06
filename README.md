# react-native-ftp-client

A ftp client library for react native
Thanks for [react-native-ftp](https://github.com/ne0z/react-native-ftp).
Get inspired from it, but almost rewrite every corner.

1. support three operations
    * list ftp dir.  
    * upload file to ftp.  
    * download file from ftp.
    * remove file or dir from ftp.  

2. NO session, which means treating each operation as a session.  
   Therefore, it is easier to use for javascript client even introduce some overhead on login and logout.  

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