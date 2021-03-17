//
//  DKViewController.m
//  DKLivePhotoKit
//
//  Created by DarrenKong on 03/15/2021.
//  Copyright (c) 2021 DarrenKong. All rights reserved.
//

#import "DKViewController.h"
#import <TZImagePickerController/TZImagePickerController.h>
#import <AFNetworking/AFNetworking.h>
#import "DKLivePhotoKit-umbrella.h"

@interface DKViewController ()<TZImagePickerControllerDelegate>

@end

@implementation DKViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    UIButton *showAlert = [UIButton buttonWithType:UIButtonTypeCustom];
    [showAlert setTitle:@"Url Asset" forState:UIControlStateNormal];
    showAlert.frame = CGRectMake(CGRectGetMidX(self.view.frame) - 80, CGRectGetMidY(self.view.frame) - 20, 160, 40);
    showAlert.layer.borderWidth = 1;
    showAlert.layer.borderColor = UIColor.blueColor.CGColor;
    [showAlert setTitleColor:UIColor.blueColor forState:UIControlStateNormal];
    [showAlert addTarget:self action:@selector(showAlert) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:showAlert];
    
    UIButton *showSelectAlert = [UIButton buttonWithType:UIButtonTypeCustom];
    [showSelectAlert setTitle:@"Local Asset" forState:UIControlStateNormal];
    showSelectAlert.frame = CGRectMake(CGRectGetMinX(showAlert.frame), CGRectGetMaxY(showAlert.frame) + 20, 160, 40);
    showSelectAlert.layer.borderWidth = 1;
    showSelectAlert.layer.borderColor = UIColor.blueColor.CGColor;
    [showSelectAlert setTitleColor:UIColor.blueColor forState:UIControlStateNormal];
    [showSelectAlert addTarget:self action:@selector(showSelectAlert) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:showSelectAlert];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// MARK: - TZImagePickerControllerDelegate

- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingVideo:(UIImage *)coverImage sourceAssets:(id)asset {
    
    [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:nil resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
        AVURLAsset *urlAsset = (AVURLAsset *)asset;
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:@"Generating..." preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertController animated:YES completion:nil];
        [[DKLivePhotoManager sharedManager] saveLivePhotoWithAsset:urlAsset completionHandler:^(BOOL success) {
            [alertController dismissViewControllerAnimated:YES completion:nil];
            if (success) {
                NSLog(@"success");
                
            } else {
                NSLog(@"fail");
            }
        }];
    }];
    
}

// MARK: - Private Methods
- (void)showAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"title" message:@"message" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okButton = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *Action) {
        UITextField *textField = alert.textFields.firstObject; // 设置第一响应者
        NSLog(@"%@", textField.text);
        if (textField.text.length > 0) {
            AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
            
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:textField.text]];
            // 网络 movie 需要下载到本地，再转换成 LivePhoto
            NSURLSessionDownloadTask *downTask = [manager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
                //打印下载进度
                NSLog(@"%f", 1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
            } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
                NSString *fullPath = [filePath stringByAppendingPathComponent:response.suggestedFilename];
                
                NSLog(@"%@", fullPath);
                return [NSURL fileURLWithPath:fullPath];
            } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                NSLog(@"%@", filePath);
                NSLog(@"completionHandler----%@", error);
                if (!error) {
                    AVURLAsset *urlAsset = [[AVURLAsset alloc] initWithURL:filePath options:nil];
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:@"Generating..." preferredStyle:UIAlertControllerStyleAlert];
                    [self presentViewController:alertController animated:YES completion:nil];
                    [[DKLivePhotoManager sharedManager] saveLivePhotoWithAsset:urlAsset completionHandler:^(BOOL success) {
                        [alertController dismissViewControllerAnimated:YES completion:nil];
                        if (success) {
                            NSLog(@"success");
                        } else {
                            NSLog(@"fail");
                        }
                    }];
                }
            }];
            
            [downTask resume];
        }
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Network movie source";
        textField.text = @"https://aweme.snssdk.com/aweme/v1/playwm/?video_id=v0300f460000c17a21d7snaft7qqno80";
    }];
    [alert addAction:okButton];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSelectAlert {
    TZImagePickerController *imagePickerVC = [[TZImagePickerController alloc] initWithMaxImagesCount:1 delegate:self];
    imagePickerVC.allowPickingImage = NO;
    imagePickerVC.allowPickingVideo = YES;
    [self presentViewController:imagePickerVC animated:YES completion:nil];
}

@end
