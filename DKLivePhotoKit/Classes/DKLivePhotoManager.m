//
//  DKLivePhotoManager.m
//  DKLivePhotoKit
//
//  Created by Darren on 2021/3/15.
//

#import "DKLivePhotoManager.h"
#import "DKLivePhotoGenerator.h"
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface DKLivePhotoManager ()

@property (nonatomic, copy) NSString *genUUID;

@end

@implementation DKLivePhotoManager

+ (instancetype)sharedManager {
    static DKLivePhotoManager *_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (void)saveLivePhotoWithAsset:(AVURLAsset *)asset completionHandler:(void (^)(BOOL))completionHandler {
    BOOL result = NO;
    do {
        result = [self generateStillImage:CMTimeGetSeconds(kCMTimeZero) urlAsset:asset];
        if (!result) {
            !completionHandler?:completionHandler(NO);
            break;
        }
        
        [self removeFile:kPathMovieFile];
        DKLivePhotoGenerator *generator = [[DKLivePhotoGenerator alloc] initWithAsset:asset];
        [generator writeMovWithPath:kPathMovieFile assetIdentifier:self.genUUID];
        
        result = [[NSFileManager defaultManager] fileExistsAtPath:kPathMovieFile];
        if (!result) {
            !completionHandler?:completionHandler(NO);
            break;
        }
        result = YES;
    } while (NO);
    
    if (result) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
            [request addResourceWithType:PHAssetResourceTypePhoto fileURL:[NSURL fileURLWithPath:kPathImageFile] options:nil];
            if (@available(iOS 9.1, *)) {
                [request addResourceWithType:PHAssetResourceTypePairedVideo fileURL:[NSURL fileURLWithPath:kPathMovieFile] options:nil];
            } else {
                [request addResourceWithType:PHAssetResourceTypeVideo fileURL:[NSURL fileURLWithPath:kPathMovieFile] options:nil];
            }
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                !completionHandler?:completionHandler(success);
            });
        }];
    }
}

- (void)saveLivePhotoWithPath:(NSString *)path completionHandler:(void (^)(BOOL))completionHandler {
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:path] options:nil];
    if (asset) {
        [self saveLivePhotoWithAsset:asset completionHandler:completionHandler];
    } else {
        !completionHandler?:completionHandler(NO);
    }
}


// Private Methods

- (BOOL)generateStillImage:(NSTimeInterval)time urlAsset:(AVURLAsset *)asset {
    AVAssetImageGenerator *imageGen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    [imageGen setAppliesPreferredTrackTransform:YES];
    imageGen.requestedTimeToleranceBefore = kCMTimeZero;
    imageGen.requestedTimeToleranceAfter = kCMTimeZero;
    NSError *error = nil;
    CMTime cutPoint = CMTimeMakeWithSeconds(time, NSEC_PER_SEC);
    
    CGImageRef ref = [imageGen copyCGImageAtTime:cutPoint actualTime:nil error:&error];
    
    if(error) return NO;
    
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    
    NSDictionary *kFigAppleMakerNote_AssetIdentifier = [NSDictionary dictionaryWithObject:self.genUUID forKey:@"17"];
    [metadata setObject:kFigAppleMakerNote_AssetIdentifier forKey:@"{MakerApple}"];
    
    NSMutableData *imageData = [[NSMutableData alloc] init];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((CFMutableDataRef)imageData, kUTTypeJPEG, 1, nil);
    CGImageDestinationAddImage(dest, ref, (CFDictionaryRef)metadata);
    CGImageDestinationFinalize(dest);
    
    [imageData writeToFile:kPathImageFile atomically:YES];
    
    return YES;
}

- (BOOL)removeFile:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        NSError *error = nil;
        [fm removeItemAtPath:path error:&error];
        if (error) {
            return NO;
        }
    }
    return YES;
}


// MARK: - Getter

- (NSString *)genUUID {
    if (!_genUUID) {
        _genUUID = [[NSUUID UUID] UUIDString];
    }
    return _genUUID;
}

@end
