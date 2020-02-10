import { NativeModules, NativeEventEmitter,EmitterSubscription } from 'react-native';

const { RNFtpClient } = NativeModules;
const RNFtpClientEventEmitter = new NativeEventEmitter(RNFtpClient);

export const enum FtpFileType {
        Dir = "dir",
        File = "file",
        Link = "link",
        Unknown = "unknown",
    };
export interface ListItem{
        name:string,
        type: FtpFileType,
        size:number,
        timestamp:Date,
    };
export interface FtpSetupConfiguration{
        ip_address:string,
        port:number,
        username:string,
        password:string
    };

module FtpClient {
    function getEnumFromString(typeString:string):FtpFileType {
        switch (typeString) {
            case "dir":
                return FtpFileType.Dir;    
            case "link":
                return FtpFileType.Link;
            case "file":
                return FtpFileType.File;
            case "unknown":    
            default:
                return FtpFileType.Unknown;
        }
    }

    export function setup (config:FtpSetupConfiguration) {
        RNFtpClient.setup(config.ip_address,config.port,config.username,config.password);
    }
    
    export async function list (remote_path:string):Promise<Array<ListItem>> {
        const files = await RNFtpClient.list(remote_path);
        return files.map((f:{name:string,type:string,size:number,timestamp:string})=> {
            return {
                name:f.name,
                type:getEnumFromString(f.type),
                size:+f.size,
                timestamp:new Date(f.timestamp)
            };});
    }

    export async function uploadFile (local_path:string,remote_path:string):Promise<void> {
        return RNFtpClient.uploadFile(local_path,remote_path);
    }

    export async function cancelUploadFile (token:string):Promise<void> {
        return RNFtpClient.cancelUploadFile(token);
    }

    export function addProgressListener(listener: ( data:{token:string, percentage:number}) => void):EmitterSubscription  {
        return RNFtpClientEventEmitter.addListener("Progress",listener);
    }

    export async function remove(remote_path:string):Promise<void>{
        return RNFtpClient.remove(remote_path);
    }
};

export default FtpClient;