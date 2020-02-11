# react-native-ftp-client

A ftp client library for react native
Thanks for [react-native-ftp](https://github.com/ne0z/react-native-ftp).
Get inspired from it, but almost rewrite every corner.

1. support three operations
    * list ftp dir.  
    * upload file to ftp.  
    * remove file or dir from ftp.  

2. NO session, which means treating each operation as a session.  
   Therefore, it is easier to use for javascript client even introduce some overhead on login and logout.  
