//
//  DKLivePhotoGenerator.m
//  DKLivePhotoKit
//
//  Created by Darren on 2021/3/15.
//

#import "DKLivePhotoGenerator.h"
#import <AVFoundation/AVFoundation.h>

@interface DKLivePhotoGenerator ()

@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) AVURLAsset *asset;
@property (nonatomic, assign) CMTimeRange dummyTimeRange;

@end

static NSString *const kContentIdentifier = @"com.apple.quicktime.content.identifier";
static NSString *const kStillImageTime = @"com.apple.quicktime.still-image-time";
static NSString *const kSpaceQuickTimeMetaData = @"mdta";

@implementation DKLivePhotoGenerator

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _path = path;
        _dummyTimeRange = CMTimeRangeMake(CMTimeMake(0, 1000), CMTimeMake(200, 3000));
    }
    return self;
}

- (instancetype)initWithAsset:(AVURLAsset *)asset {
    self = [super init];
    if (self) {
        _asset = asset;
        _dummyTimeRange = CMTimeRangeMake(CMTimeMake(0, 1000), CMTimeMake(200, 3000));
    }
    return self;
}

// MARK: - Public

- (void)writeMovWithPath:(NSString *)destPath assetIdentifier:(NSString *)identifier {
    @try {
        AVAssetTrack *track = [self.asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
        AVAssetTrack *audioTrack = [self.asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
        if (!track) {
            NSLog(@"not found video track");
            return;
        }
        AVAssetReaderTrackOutput *output = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:@{ (NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];
        AVAssetReaderTrackOutput *audioOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:@{AVFormatIDKey :@(kAudioFormatLinearPCM)}];
        
        NSError *error = nil;
        AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:self.asset error: &error];
        if (reader) {
            [reader addOutput:output];
            if ([reader canAddOutput:audioOutput]) {
                [reader addOutput:audioOutput];
            }
            NSError *writerError = nil;
            AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:destPath] fileType:AVFileTypeQuickTimeMovie error:&writerError];
            if (writer) {
                writer.metadata = @[[self metadataForAssetIdentifier:identifier]];
                
                AVAssetWriterInput *input = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:[self getVideoSettingFrom:track.naturalSize]];
                input.expectsMediaDataInRealTime = YES;
                input.transform = track.preferredTransform;
                [writer addInput:input];
                
                NSDictionary *audioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                                       [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                                       [ NSNumber numberWithInt: 1], AVNumberOfChannelsKey,
                                                       [ NSNumber numberWithFloat: 44100], AVSampleRateKey,
                                                       [ NSNumber numberWithInt: 128000], AVEncoderBitRateKey,
                                                       nil];
                AVAssetWriterInput *audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:[audioTrack mediaType] outputSettings:audioSettings];
                audioInput.expectsMediaDataInRealTime = true;
                audioInput.transform = audioTrack.preferredTransform;
                [writer addInput:audioInput];
                
                AVAssetWriterInputMetadataAdaptor *adapter = [self getMetadataAdapter];
                [writer addInput:adapter.assetWriterInput];
                
                [writer startWriting];
                [reader startReading];
                [writer startSessionAtSourceTime:kCMTimeZero];
                
                AVTimedMetadataGroup *group = [[AVTimedMetadataGroup alloc] initWithItems:@[[self metadataForStillImageTime]] timeRange:self.dummyTimeRange];
                [adapter appendTimedMetadataGroup:group];
                
                dispatch_queue_t writerQueue = dispatch_queue_create("assetAudioWriterQueue", NULL);
                [input requestMediaDataWhenReadyOnQueue:writerQueue usingBlock:^{
                    while (input.isReadyForMoreMediaData) {
                        if (reader.status == AVAssetReaderStatusReading) {
                            CMSampleBufferRef buffer = [output copyNextSampleBuffer];
                            CMSampleBufferRef audioBuffer = [audioOutput copyNextSampleBuffer];
                            if (audioBuffer) {
                                [audioInput appendSampleBuffer:audioBuffer];
                                CFRelease(audioBuffer);
                            }
                            if (buffer) {
                                BOOL result = [input appendSampleBuffer:buffer];
                                CFRelease(buffer);
                                if (!result) {
                                    NSLog(@"cannot wirte:%@", writer.error);
                                    [reader cancelReading];
                                }
                            }
                        } else {
                            [input markAsFinished];
                            [writer finishWritingWithCompletionHandler:^{
                                if (writer.error) {
                                    NSLog(@"cannot write: %@", writer.error);
                                } else {
                                    NSLog(@"finish writing.");
                                }
                            }];
                        }
                    }
                }];
                while (writer.status == AVAssetWriterStatusWriting) {
                    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
                }
                if (writer.error) {
                    NSLog(@"cannot wirte: %@", writer.error);
                }
            } else {
                NSLog(@"writerError: %@", writerError);
            }
        } else {
            NSLog(@"error:%@", error);
        }
        
    } @catch (NSException *exception) {
        NSLog(@"cannot write: %@", exception);
    } @finally {
        
    }
}

// MARK: - Private

- (AVMetadataItem *)metadataForAssetIdentifier:(NSString *)identifier {
    AVMutableMetadataItem *item = [[AVMutableMetadataItem alloc] init];
    item.key = kContentIdentifier;
    item.keySpace = kSpaceQuickTimeMetaData;
    item.value = identifier;
    item.dataType = @"com.apple.metadata.datatype.UTF-8";
    return item;
}

- (AVMetadataItem *)metadataForStillImageTime {
    AVMutableMetadataItem *item = [[AVMutableMetadataItem alloc] init];
    item.key = kStillImageTime;
    item.keySpace = kSpaceQuickTimeMetaData;
    item.value = @(0);
    item.dataType = @"com.apple.metadata.datatype.int8";
    return item;
}

- (NSDictionary *)getVideoSettingFrom:(CGSize)size {
    return @{
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: @(size.width),
        AVVideoHeightKey: @(size.height)
    };
}

- (AVAssetWriterInputMetadataAdaptor *)getMetadataAdapter {
    NSDictionary *spec = @{
        (NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier: [NSString stringWithFormat:@"%@/%@", kSpaceQuickTimeMetaData, kStillImageTime],
        (NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType: @"com.apple.metadata.datatype.int8",
    };
    CMFormatDescriptionRef desc = NULL;
    CMMetadataFormatDescriptionCreateWithMetadataSpecifications(kCFAllocatorDefault, kCMMetadataFormatType_Boxed, (__bridge CFArrayRef)@[spec], &desc);
    AVAssetWriterInput *input = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeMetadata outputSettings:nil sourceFormatHint:desc];
    CFRelease(desc);
    return [AVAssetWriterInputMetadataAdaptor assetWriterInputMetadataAdaptorWithAssetWriterInput:input];
}

// MARK: - Getter

- (AVURLAsset *)asset {
    if (!_asset) {
        _asset = ({
            AVURLAsset *urlAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:self.path] options:nil];
            urlAsset;
        });
    }
    return _asset;
}

@end
