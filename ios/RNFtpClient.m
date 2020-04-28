
#import "RNFtpClient.h"
#import "LxFTPRequest.h"
#import <sys/dirent.h>

NSString* const RNFTPCLIENT_PROGRESS_EVENT_NAME = @"Progress";

NSString* const RNFTPCLIENT_ERROR_CODE_LIST = @"RNFTPCLIENT_ERROR_CODE_LIST";
NSString* const RNFTPCLIENT_ERROR_CODE_UPLOAD = @"RNFTPCLIENT_ERROR_CODE_UPLOAD";
NSString* const RNFTPCLIENT_ERROR_CODE_CANCELUPLOAD = @"RNFTPCLIENT_ERROR_CODE_CANCELUPLOAD";
NSString* const RNFTPCLIENT_ERROR_CODE_REMOVE = @"RNFTPCLIENT_ERROR_CODE_REMOVE";
NSString* const RNFTPCLIENT_ERROR_CODE_DOWNLOAD = @"RNFTPCLIENT_ERROR_CODE_DOWNLOAD";

NSInteger const MAX_UPLOAD_COUNT = 10;
NSInteger const MAX_DOWNLOAD_COUNT = 10;

NSString* const ERROR_MESSAGE_CANCELLED = @"ERROR_MESSAGE_CANCELLED";

#pragma mark - FTPTaskData
@interface FTPTaskData:NSObject
@property(readwrite) NSInteger lastPercentage;
@property(readwrite, strong) LxFTPRequest *request;
@end

@implementation FTPTaskData
@end

#pragma mark - RNFtpClient
@implementation RNFtpClient {
    NSString* url;
    NSString* user;
    NSString* password;
    NSMutableDictionary* uploadTokens;
    bool hasListeners;
    NSMutableDictionary* downloadTokens;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

 - (instancetype)init {
     if (self = [super init]) {
         // Initialize self
         self->uploadTokens = [[NSMutableDictionary alloc]initWithCapacity:MAX_UPLOAD_COUNT];
         self->downloadTokens = [[NSMutableDictionary alloc]initWithCapacity:MAX_DOWNLOAD_COUNT];
     }
     return self;
 }
+ (BOOL)requiresMainQueueSetup
{
  return NO;  // only do this if your module initialization relies on calling UIKit!
}
RCT_EXPORT_MODULE(RNFtpClient)

-(void)startObserving {
    hasListeners = YES;
}

-(void)stopObserving {
    hasListeners = NO;
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[RNFTPCLIENT_PROGRESS_EVENT_NAME];
}

- (void)sendProgressEventToToken:(NSString*) token withPercentage:(NSInteger )percentage
{
    if (hasListeners) { // Only send events if anyone is listening
        NSLog(@"send percentage %ld",percentage);
        [self sendEventWithName:RNFTPCLIENT_PROGRESS_EVENT_NAME body:@{@"token":token, @"percentage": @(percentage)}];
    }
}

- (void)sendUploadProgressEventToToken:(NSString*) token withPercentage:(NSInteger )percentage
{
    FTPTaskData* upload = self->uploadTokens[token];
    if(percentage == upload.lastPercentage){
        NSLog(@"the percentage is same %ld",percentage);
        return;
    }
    upload.lastPercentage = percentage;
    [self sendProgressEventToToken:token withPercentage:percentage];
}
- (void)sendDownloadProgressEventToToken:(NSString*) token withPercentage:(NSInteger )percentage
{
    FTPTaskData* download = self->downloadTokens[token];
    if(percentage == download.lastPercentage){
        NSLog(@"the percentage is same %ld",percentage);
        return;
    }
    download.lastPercentage = percentage;
    [self sendProgressEventToToken:token withPercentage:percentage];
}
-(NSError*) makeErrorFromDomain:(CFStreamErrorDomain) domain errorCode:( NSInteger) error errorMessage:(NSString *)errorMessage
{
    NSErrorDomain nsDomain = NSCocoaErrorDomain;
    switch (domain){
        case kCFStreamErrorDomainCustom:
            nsDomain = NSCocoaErrorDomain;
            break;
        case kCFStreamErrorDomainPOSIX:
            nsDomain = NSPOSIXErrorDomain;
            break;
        case kCFStreamErrorDomainMacOSStatus:
            nsDomain = NSOSStatusErrorDomain;
            break;
    }
    return [NSError errorWithDomain:nsDomain code:error userInfo:@{NSLocalizedDescriptionKey:errorMessage}];
}

-(NSString*) makeErrorMessageWithPrefix:(NSString*) prefix domain:(CFStreamErrorDomain) domain errorCode:( NSInteger) error errorMessage:(NSString *)errorMessage
{
    NSString* nsDomain = @"unknown_domain";
    switch (domain){
        case kCFStreamErrorDomainCustom:
            nsDomain = @"Cocoa";
            break;
        case kCFStreamErrorDomainPOSIX:
        {
            errorMessage = [NSString stringWithUTF8String:strerror((int)error)];
            nsDomain =  @"Posix";
            break;
        }
        case kCFStreamErrorDomainMacOSStatus:
            nsDomain = @"OSX";
            break;
    }
    return [NSString stringWithFormat:@"%@ %@(%ld) %@",prefix, nsDomain,error,errorMessage];
}

RCT_REMAP_METHOD(setup,
                 setupWithIp:(NSString*) ip
                 AndPort:(NSInteger) port
                 AndUserName:(NSString*) userName
                 AndPassword:(NSString*) password)
{
    self->url = [NSString stringWithFormat:@"ftp://%@:%ld", ip, (long)port ];
    self->user = userName;
    self->password = password;
}

-(NSString*) typeStringFromType:(NSInteger) type
{
    switch (type) {
        case DT_DIR:
            return @"dir";
        case DT_REG:
            return @"file";
        case DT_LNK:
            return @"link";
        default:
            break;
    }
    return @"unknown";
}
-(NSString*) ISO8601StringFromNSDate:(NSDate*) date
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    [dateFormatter setCalendar:[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]];

    return [dateFormatter stringFromDate:date];
}

RCT_REMAP_METHOD(list,
                 listRemotePath:(NSString*)remotePath
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    LxFTPRequest *request = [LxFTPRequest resourceListRequest];
    request.serverURL = [[NSURL URLWithString:self->url] URLByAppendingPathComponent:remotePath];
    request.username = self->user;
    request.password = self->password;

    request.successAction = ^(Class resultClass, id result) {
        NSArray *resultArray = (NSArray *)result;
        NSMutableArray *files = [[NSMutableArray alloc] initWithCapacity:[resultArray count]];
        for (NSDictionary* file in resultArray) {
            NSString* name = file[(__bridge NSString *)kCFFTPResourceName];
            NSInteger type = [file[(__bridge NSString *)kCFFTPResourceType] integerValue];
            NSInteger size = [file[(__bridge NSString *)kCFFTPResourceSize] integerValue];
            NSDate* timestamp = file[(__bridge NSString *)kCFFTPResourceModDate];
            NSDictionary* f = @{@"name":name,@"type":[self typeStringFromType:type],@"size":@(size),@"timestamp":[self ISO8601StringFromNSDate:timestamp]};
            [files addObject:f];
        }
        resolve([files copy]);
    };
    request.failAction = ^(CFStreamErrorDomain domain, NSInteger error, NSString *errorMessage) {
        NSLog(@"domain = %ld, error = %ld, errorMessage = %@", domain, error, errorMessage); //
        NSError* nsError = [self makeErrorFromDomain:domain errorCode:error errorMessage:errorMessage];
        NSString* message = [self makeErrorMessageWithPrefix:@"list error" domain:domain errorCode:error errorMessage:errorMessage];
        reject(RNFTPCLIENT_ERROR_CODE_LIST,message,nsError);
    };
    [request start];

}

-(NSString*) makeTokenByLocalPath:(NSString*) localPath andRemotePath:(NSString*) remotePath
{
    return [NSString stringWithFormat:@"%@=>%@",localPath,remotePath ];
}

-(NSString*) getRemotePathFromToken:(NSString*) token
{
    NSArray* tokenParts = [token componentsSeparatedByString:@"=>"];
    if(token && token.length > 1){
        return tokenParts[1];
    }else{
        return nil;
    }
}

- (NSDictionary *)constantsToExport
{
  return @{ ERROR_MESSAGE_CANCELLED: ERROR_MESSAGE_CANCELLED };
}

RCT_REMAP_METHOD(uploadFile,
                 uploadFileFromLocal:(NSString*)localPath
                 toRemote:(NSString*)remotePath
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    if([[NSFileManager defaultManager] fileExistsAtPath:localPath] == NO)
    {
        reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,@"local file is not exist",nil);
        return ;
    }

    NSString* token = [self makeTokenByLocalPath:localPath andRemotePath:remotePath];
    if(self->uploadTokens[token]){
        reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,@"same upload is runing",nil);
        return;
    }
    if([self->uploadTokens count] >= MAX_UPLOAD_COUNT){
        reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,@"has reach max uploading tasks", nil);
        return;
    }
    LxFTPRequest *request = [LxFTPRequest uploadRequest];
    NSURL* serverURL = [[NSURL URLWithString:self->url] URLByAppendingPathComponent:remotePath];
    request.serverURL = serverURL;
    if (!request.serverURL) {
        reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,[NSString stringWithFormat:@"server url is invalide %@",serverURL],nil);
        return;
    }
    NSURL* localFileURL = [NSURL fileURLWithPath:localPath];
    request.localFileURL = localFileURL;
    if (!request.localFileURL) {
        reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,[NSString stringWithFormat:@"local url is invalide %@",localFileURL],nil);
        return;
    }

    request.username = self->user;
    request.password = self->password;

    request.progressAction = ^(NSInteger totalSize, NSInteger finishedSize, CGFloat finishedPercent) {
        NSLog(@"totalSize = %ld, finishedSize = %ld, finishedPercent = %f", (long)totalSize, (long)finishedSize, finishedPercent); //
        [self sendUploadProgressEventToToken:token withPercentage:finishedPercent];
    };
    request.successAction = ^(Class resultClass, id result) {
        NSLog(@"Upload file succcess %@", result);
        [self sendUploadProgressEventToToken:token withPercentage:100];
        [self->uploadTokens removeObjectForKey:token];
        resolve(@(true));
    };
    request.failAction = ^(CFStreamErrorDomain domain, NSInteger error, NSString *errorMessage) {
        [self->uploadTokens removeObjectForKey:token];

        NSLog(@"domain = %ld, error = %ld, errorMessage = %@", domain, (long)error, errorMessage); //

        if([errorMessage isEqual:ERROR_MESSAGE_CANCELLED]){
            reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,ERROR_MESSAGE_CANCELLED,nil);
        }else{
            NSError* nsError = [self makeErrorFromDomain:domain errorCode:error errorMessage:errorMessage];
            NSString* message = [self makeErrorMessageWithPrefix:@"upload error" domain:domain errorCode:error errorMessage:errorMessage];
            reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,message,nsError);
        }
    };
    BOOL started = [request start];
    if(started){
        FTPTaskData* upload = [[FTPTaskData alloc]init];
        upload.lastPercentage = -1;
        upload.request = request;

        [self->uploadTokens setObject:upload forKey:token];
        [self sendUploadProgressEventToToken:token withPercentage:0];
    }else{
        reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,@"start uploading failed",nil);
    }

}

-(void) clearRemoteFileByToken:(NSString*) token
{
    NSString* remotePath = [self getRemotePathFromToken:token];
    [self removeWithRemotePath:remotePath resolver:^(id result) {
        NSLog(@"clear remote file %@ success",remotePath);
    } rejecter:^(NSString *code, NSString *message, NSError *error) {
        NSLog(@"clear remote file %@ wrong", message);
    }];
}
RCT_REMAP_METHOD(cancelUploadFile,
                 cancelUploadFileWithToken:(NSString*)token
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    FTPTaskData* upload = self->uploadTokens[token];

    if(!upload){
        reject(RNFTPCLIENT_ERROR_CODE_UPLOAD,@"token is wrong",nil);
        return;
    }
    [self->uploadTokens removeObjectForKey:token];
    [upload.request stop];
    upload.request.failAction(kCFStreamErrorDomainCustom,0,ERROR_MESSAGE_CANCELLED);

    [self clearRemoteFileByToken:token];
    resolve([NSNumber numberWithBool:TRUE]);
}

//remove file or dir
RCT_REMAP_METHOD(remove,
                 removeWithRemotePath:(NSString*)remotePath
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    LxFTPRequest *request = [LxFTPRequest destoryResourceRequest];
    NSURL* serverURL = [[NSURL URLWithString:self->url] URLByAppendingPathComponent:remotePath];
    request.serverURL = serverURL;
    if (!request.serverURL) {
        reject(RNFTPCLIENT_ERROR_CODE_REMOVE,[NSString stringWithFormat:@"server url is invalide %@",serverURL],nil);
        return;
    }
    request.username = self->user;
    request.password = self->password;

    request.successAction = ^(Class resultClass, id result) {
        NSLog(@"Remove file succcess %@", result);
        resolve([NSNumber numberWithBool:TRUE]);
    };
    request.failAction = ^(CFStreamErrorDomain domain, NSInteger error, NSString *errorMessage) {
        NSLog(@"domain = %ld, error = %ld, errorMessage = %@", domain, error, errorMessage);
        NSError* nsError = [self makeErrorFromDomain:domain errorCode:error errorMessage:errorMessage];
        NSString* message = [self makeErrorMessageWithPrefix:@"remove error" domain:domain errorCode:error errorMessage:errorMessage];
        reject(RNFTPCLIENT_ERROR_CODE_REMOVE,message,nsError);
    };
    [request start];
}

#pragma mark - Downloading
-(NSString*) makeDownloadTokenByLocalPath:(NSString*) localPath andRemotePath:(NSString*) remotePath
{
    return [NSString stringWithFormat:@"%@<=%@",localPath,remotePath ];
}

-(NSString*) getLocalFilePath:(NSString*) path fromRemotePath:(NSString*) remotePath
{
    if([path hasSuffix:@"/"]){
        NSString* fileName = [remotePath lastPathComponent];
        return [path stringByAppendingPathComponent:fileName];
    }else{
        return path;
    }
}

-(void) clearLocalFileByURL:(NSURL*) localFileURL
{
    [[NSFileManager defaultManager] removeItemAtURL:localFileURL error:nil];
}

RCT_REMAP_METHOD(downloadFile,
                 downloadFileToLocal:(NSString*)localPath
                 fromRemote:(NSString*)remotePath
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"downloadFile %@<=%@",localPath,remotePath);
    NSString* token = [self makeDownloadTokenByLocalPath:localPath andRemotePath:remotePath];
    if(self->downloadTokens[token]){
        reject(RNFTPCLIENT_ERROR_CODE_DOWNLOAD,@"same download is runing",nil);
        return;
    }
    if([self->downloadTokens count] >= MAX_DOWNLOAD_COUNT){
        reject(RNFTPCLIENT_ERROR_CODE_DOWNLOAD,@"has reach max uploading tasks", nil);
        return;
    }
    if([remotePath hasSuffix:@"/"]){
        reject(RNFTPCLIENT_ERROR_CODE_DOWNLOAD,@"remote path can not be a dir", nil);
        return;
    }

    NSString* localFilePath = [self getLocalFilePath:localPath fromRemotePath:remotePath];
    if([[NSFileManager defaultManager] fileExistsAtPath:localFilePath] == YES)
    {
        reject(RNFTPCLIENT_ERROR_CODE_DOWNLOAD,@"local file is exist",nil);
        return ;
    }
    LxFTPRequest *request = [LxFTPRequest downloadRequest];
    NSURL* serverURL = [[NSURL URLWithString:self->url] URLByAppendingPathComponent:remotePath];
    request.serverURL = serverURL;
    if (!request.serverURL) {
        reject(RNFTPCLIENT_ERROR_CODE_DOWNLOAD,[NSString stringWithFormat:@"server url is invalide %@",serverURL],nil);
        return;
    }
    NSURL* localFileURL = [NSURL fileURLWithPath:localFilePath];
    request.localFileURL = localFileURL;
    if (!request.localFileURL) {
        reject(RNFTPCLIENT_ERROR_CODE_DOWNLOAD,[NSString stringWithFormat:@"local url is invalide %@",localFileURL],nil);
        return;
    }

    request.username = self->user;
    request.password = self->password;

    request.progressAction = ^(NSInteger totalSize, NSInteger finishedSize, CGFloat finishedPercent) {
        NSLog(@"totalSize = %ld, finishedSize = %ld, finishedPercent = %f", (long)totalSize, (long)finishedSize, finishedPercent); //
        [self sendDownloadProgressEventToToken:token withPercentage:finishedPercent];
    };
    request.successAction = ^(Class resultClass, id result) {
        NSLog(@"Download file succcess %@", result);
        [self sendDownloadProgressEventToToken:token withPercentage:100];
        [self->downloadTokens removeObjectForKey:token];
        resolve(@(true));
    };
    request.failAction = ^(CFStreamErrorDomain domain, NSInteger error, NSString *errorMessage) {
        [self->downloadTokens removeObjectForKey:token];

        NSLog(@"domain = %ld, error = %ld, errorMessage = %@", domain, (long)error, errorMessage); //

        if([errorMessage isEqual:ERROR_MESSAGE_CANCELLED]){
            reject(RNFTPCLIENT_ERROR_CODE_DOWNLOAD,ERROR_MESSAGE_CANCELLED,nil);
        }else{
            NSError* nsError = [self makeErrorFromDomain:domain errorCode:error errorMessage:errorMessage];
            NSString* message = [self makeErrorMessageWithPrefix:@"download error" domain:domain errorCode:error errorMessage:errorMessage];
            reject(RNFTPCLIENT_ERROR_CODE_DOWNLOAD,message,nsError);
        }
        [self clearLocalFileByURL:localFileURL];
    };
    BOOL started = [request start];
    if(started){
        FTPTaskData* download = [[FTPTaskData alloc]init];
        download.lastPercentage = -1;
        download.request = request;

        [self->downloadTokens setObject:download forKey:token];
        [self sendDownloadProgressEventToToken:token withPercentage:0];
    }else{
        reject(RNFTPCLIENT_ERROR_CODE_DOWNLOAD,@"start download failed",nil);
    }

}

RCT_REMAP_METHOD(cancelDownloadFile,
                 cancelDownloadFileWithToken:(NSString*)token
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    FTPTaskData* task = self->downloadTokens[token];

    if(!task){
        reject(RNFTPCLIENT_ERROR_CODE_DOWNLOAD,@"token is wrong",nil);
        return;
    }
    [self->downloadTokens removeObjectForKey:token];
    [task.request stop];
    task.request.failAction(kCFStreamErrorDomainCustom,0,ERROR_MESSAGE_CANCELLED);

    resolve([NSNumber numberWithBool:TRUE]);
}
@end
  
