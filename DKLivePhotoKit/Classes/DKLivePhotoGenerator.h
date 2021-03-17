//
//  DKLivePhotoGenerator.h
//  DKLivePhotoKit
//
//  Created by Darren on 2021/3/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AVURLAsset;

@interface DKLivePhotoGenerator : NSObject

- (instancetype)initWithPath:(nonnull NSString *)path;
- (instancetype)initWithAsset:(nonnull AVURLAsset *)asset;

- (void)writeMovWithPath:(nonnull NSString *)destPath assetIdentifier:(nonnull NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
