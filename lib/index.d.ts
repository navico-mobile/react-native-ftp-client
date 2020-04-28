import { EmitterSubscription } from 'react-native';
export declare const enum FtpFileType {
    Dir = "dir",
    File = "file",
    Link = "link",
    Unknown = "unknown"
}
export interface ListItem {
    name: string;
    type: FtpFileType;
    size: number;
    timestamp: Date;
}
export interface FtpSetupConfiguration {
    ip_address: string;
    port: number;
    username: string;
    password: string;
}
declare module FtpClient {
    function setup(config: FtpSetupConfiguration): void;
    function list(remote_path: string): Promise<Array<ListItem>>;
    function uploadFile(local_path: string, remote_path: string): Promise<void>;
    function cancelUploadFile(token: string): Promise<void>;
    function addProgressListener(listener: (data: {
        token: string;
        percentage: number;
    }) => void): EmitterSubscription;
    function remove(remote_path: string): Promise<void>;
    const ERROR_MESSAGE_CANCELLED: string;
    function downloadFile(local_path: string, remote_path: string): Promise<void>;
    function cancelDownloadFile(token: string): Promise<void>;
}
export default FtpClient;
