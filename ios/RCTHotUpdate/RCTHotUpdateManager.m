//
//  RCTHotUpdateManager.m
//  RCTHotUpdate
//
//  Created by lvbingru on 16/4/1.
//  Copyright © 2016年 erica. All rights reserved.
//

#import "RCTHotUpdateManager.h"
#import "ZipArchive.h"
#import "BSDiff.h"
#import "bspatch.h"

@implementation RCTHotUpdateManager {
    dispatch_queue_t _opQueue;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _opQueue = dispatch_queue_create("cn.reactnative.hotupdate", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)createDir:(NSString *)dir
{
    __block BOOL success = false;
    
    dispatch_sync(_opQueue, ^{
        BOOL isDir;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:dir isDirectory:&isDir]) {
            if (isDir) {
                success = true;
                return;
            }
        }
        
        NSError *error;
        [fileManager createDirectoryAtPath:dir
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
        if (!error) {
            success = true;
            return;
        }
    });
    
    return success;
}

- (void)unzipFileAtPath:(NSString *)path
          toDestination:(NSString *)destination
        progressHandler:(void (^)(NSString *entry, long entryNumber, long total))progressHandler
      completionHandler:(void (^)(NSString *path, BOOL succeeded, NSError *error))completionHandler
{
    dispatch_async(_opQueue, ^{
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:destination]) {
            [[NSFileManager defaultManager] removeItemAtPath:destination error:nil];
        }
        
        [SSZipArchive unzipFileAtPath:path toDestination:destination progressHandler:^(NSString *entry, unz_file_info zipInfo, long entryNumber, long total) {
            progressHandler(entry, entryNumber, total);
        } completionHandler:^(NSString *path, BOOL succeeded, NSError *error) {
            // 解压完，移除zip文件
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            if (completionHandler) {
                completionHandler(path, succeeded, error);
            }
        }];
    });
}

- (void)bsdiffFileAtPath:(NSString *)path
              fromOrigin:(NSString *)origin
          toDestination:(NSString *)destination
      completionHandler:(void (^)(BOOL success))completionHandler
{
    dispatch_async(_opQueue, ^{
        BOOL success = [BSDiff bsdiffPatch:path origin:origin toDestination:destination];
        if (completionHandler) {
            completionHandler(success);
        }
    });
}

- (void)copyFiles:(NSDictionary *)filesDic
          fromDir:(NSString *)fromDir
            toDir:(NSString *)toDir
completionHandler:(void (^)(NSError *error))completionHandler
{
    dispatch_async(_opQueue, ^{
        for (NSString *to in filesDic.allKeys) {
            NSString *from = filesDic[to];
            if (from.length <=0) {
                from = to;
            }
            NSString *fromPath = [fromDir stringByAppendingPathComponent:from];
            NSString *toPath = [toDir stringByAppendingPathComponent:to];
            
            NSError *error = nil;
            [[NSFileManager defaultManager] moveItemAtPath:fromPath toPath:toPath error:&error];
            if (error) {
                if (completionHandler) {
                    completionHandler(error);
                }
                return;
            }
        }
        if (completionHandler) {
            completionHandler(nil);
        }
    });
}

- (void)removeFile:(NSString *)filePath
 completionHandler:(void (^)(NSError *error))completionHandler
{
    dispatch_async(_opQueue, ^{
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        if (completionHandler) {
            completionHandler(error);
        }
    });
}

@end