
package com.reactlibrary.ftpclient;

import android.util.Log;

import androidx.annotation.Nullable;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.Arguments;

import org.apache.commons.net.ftp.FTP;
import org.apache.commons.net.ftp.FTPClient;
import org.apache.commons.net.ftp.FTPFile;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.TimeZone;
import java.util.Map;

public class RNFtpClientModule extends ReactContextBaseJavaModule {

  private static final String TAG = "RNFtpClient";
  private final ReactApplicationContext reactContext;
  private String ip_address;
  private int port;
  private String username;
  private String password;
  private HashMap<String,Thread> uploadingTasks = new HashMap<>();
  private final static int MAX_UPLOAD_COUNT = 10;

  private final static String RNFTPCLIENT_PROGRESS_EVENT_NAME = "Progress";

  private final static String RNFTPCLIENT_ERROR_CODE_LOGIN = "RNFTPCLIENT_ERROR_CODE_LOGIN";
  private final static String RNFTPCLIENT_ERROR_CODE_LIST = "RNFTPCLIENT_ERROR_CODE_LIST";
  private final static String RNFTPCLIENT_ERROR_CODE_UPLOAD = "RNFTPCLIENT_ERROR_CODE_UPLOAD";
  private final static String RNFTPCLIENT_ERROR_CODE_CANCELUPLOAD = "RNFTPCLIENT_ERROR_CODE_CANCELUPLOAD";
  private final static String RNFTPCLIENT_ERROR_CODE_REMOVE = "RNFTPCLIENT_ERROR_CODE_REMOVE";
  private final static String RNFTPCLIENT_ERROR_CODE_LOGOUT = "RNFTPCLIENT_ERROR_CODE_LOGOUT";

  private final static String ERROR_MESSAGE_CANCELLED = "ERROR_MESSAGE_CANCELLED";

  public RNFtpClientModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;
  }

  @ReactMethod
  public void setup(String ip_address, int port, String username, String password){
    this.ip_address = ip_address;
    this.port = port;
    this.username = username;
    this.password = password;
  }


  private void login(FTPClient client) throws IOException{
    client.connect(this.ip_address,this.port);
    client.enterLocalPassiveMode();
    client.login(this.username, this.password);
  }

  private void logout(FTPClient client) {
    try {
      client.logout();
    }catch (IOException e){
      Log.d(TAG,"logout error",e);
    }
    try {
      if(client.isConnected()){
        client.disconnect();
      }
    }catch (IOException e){
      Log.d(TAG,"logout disconnect error",e);
    }

  }

  private String getStringByType(int type){
    switch (type)
    {
      case FTPFile.DIRECTORY_TYPE:
        return "dir";
      case FTPFile.FILE_TYPE:
        return "file";
      case FTPFile.SYMBOLIC_LINK_TYPE:
        return "link";
      case FTPFile.UNKNOWN_TYPE:
      default:
        return "unknown";
    }
  }

  private String ISO8601StringFromCalender(Calendar calendar){
    Date date = calendar.getTime();

    SimpleDateFormat sdf;
    sdf = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX");
    sdf.setTimeZone(TimeZone.getTimeZone("CET"));
    return sdf.format(date);
  }

  @ReactMethod
  public void list(final String path, final Promise promise){
    new Thread(new Runnable() {
      @Override
      public void run() {
        FTPFile[] files = new FTPFile[0];
        FTPClient client = new FTPClient();
        try {
          login(client);
          files = client.listFiles(path);
          WritableArray arrfiles = Arguments.createArray();
          for (FTPFile file : files) {
            WritableMap tmp = Arguments.createMap();
            tmp.putString("name",file.getName());
            tmp.putInt("size",(int)file.getSize());
            tmp.putString("timestamp",ISO8601StringFromCalender(file.getTimestamp()));
            tmp.putString("type",getStringByType(file.getType()));
            arrfiles.pushMap(tmp);
          }
          promise.resolve(arrfiles);
        } catch (Exception e) {
          promise.reject(RNFTPCLIENT_ERROR_CODE_LIST, e.getMessage());
        } finally {
          logout(client);
        }
      }
    }).start();
  }

  //remove file or dir
  @ReactMethod
  public void remove(final String path, final Promise promise){
    new Thread(new Runnable() {
      @Override
      public void run() {
        FTPClient client = new FTPClient();
        try {
          login(client);
          if(path.endsWith(File.separator)){
            client.removeDirectory(path);
          }else{
            client.deleteFile(path);
          }
          promise.resolve(true);
        } catch (IOException e) {
          promise.reject("ERROR",e.getMessage());
        } finally {
          logout(client);
        }
      }
    }).start();
  }

  private String makeToken(final String path,final String remoteDestinationDir ){
    return String.format("%s=>%s", path, remoteDestinationDir);
  }

  private void sendEvent(ReactContext reactContext,
                         String eventName,
                         @Nullable WritableMap params) {
    reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
            .emit(eventName, params);
  }

  private void sendProgressEventToToken(String token, int percentage){
    WritableMap params = Arguments.createMap();
    params.putString("token", token);
    params.putInt("percentage", percentage);

    Log.d(TAG,"send progress "+percentage+" to:"+token);
    this.sendEvent(this.reactContext,RNFTPCLIENT_PROGRESS_EVENT_NAME,params);
  }

  @Override
  public Map<String, Object> getConstants() {
    final Map<String, Object> constants = new HashMap();
    constants.put(ERROR_MESSAGE_CANCELLED, ERROR_MESSAGE_CANCELLED);
    return constants;
  }

  @ReactMethod
  public void uploadFile(final String path,final String remoteDestinationPath, final Promise promise){
    final String token = makeToken(path,remoteDestinationPath);
    if(uploadingTasks.containsKey(token)){
      promise.reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,"same upload is runing");
      return;
    }
    if(uploadingTasks.size() >= MAX_UPLOAD_COUNT){
      promise.reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,"has reach max uploading tasks");
      return;
    }
    final Thread t =
    new Thread(new Runnable() {
      @Override
      public void run() {
        FTPClient client = new FTPClient();
        try {
          login(client);
          client.setFileType(FTP.BINARY_FILE_TYPE);
          File localFile = new File(path);
          long totalBytes = localFile.length();
          long finishBytes = 0;

          String remoteFile = remoteDestinationPath;
          InputStream inputStream = new FileInputStream(localFile);

          Log.d(TAG,"Start uploading file");

          OutputStream outputStream = client.storeFileStream(remoteFile);
          byte[] bytesIn = new byte[4096];
          int read = 0;

          sendProgressEventToToken(token,0);
          Log.d(TAG,"Resolve token:"+token);
          int lastPercentage = 0;
          while ((read = inputStream.read(bytesIn)) != -1 && !Thread.currentThread().isInterrupted()) {
              outputStream.write(bytesIn, 0, read);
              finishBytes += read;
              int newPercentage = (int)(finishBytes*100/totalBytes);
              if(newPercentage>lastPercentage){
                sendProgressEventToToken(token,newPercentage);
                lastPercentage = newPercentage;
              }
          }
          inputStream.close();
          outputStream.close();
          Log.d(TAG,"Finish uploading");

          //if not interrupted
          if(!Thread.currentThread().isInterrupted()) {
            boolean done = client.completePendingCommand();

            if (done) {
              promise.resolve(true);
            } else {
              promise.reject(RNFTPCLIENT_ERROR_CODE_UPLOAD, localFile.getName() + " is not uploaded successfully.");
              client.deleteFile(remoteFile);
            }
          }else{
            //interupted, the file will deleted by cancel update operation
            promise.reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,ERROR_MESSAGE_CANCELLED);
          }
        } catch (IOException e) {
          promise.reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,e.getMessage());
        } finally {
          uploadingTasks.remove(token);
          logout(client);
        }
      }
    });
    t.start();
    uploadingTasks.put(token,t);
  }

  @ReactMethod
  public void cancelUploadFile(final String token, final Promise promise){

    Thread upload = uploadingTasks.get(token);

    if(upload == null){
      promise.reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,"token is wrong");
      return;
    }
    upload.interrupt();
    FTPClient client = new FTPClient();
    try{
      upload.join();
      login(client);
      String remoteFile = token.split("=>")[1];
      client.deleteFile(remoteFile);
    }catch (Exception e){
      Log.d(TAG,"cancel upload error",e);
    }finally {
      logout(client);
    }
    uploadingTasks.remove(token);
    promise.resolve(true);
  }


  @Override
  public String getName() {
    return "RNFtpClient";
  }
}
