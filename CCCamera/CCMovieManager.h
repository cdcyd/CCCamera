//
//  CCMovieManager.h
//  CCCamera
//
//  Created by cyd on 2018/8/13.
//  Copyright © 2018 cyd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CCMovieManager : NSObject

@property(nonatomic, assign) AVCaptureVideoOrientation referenceOrientation; // 视频播放方向

@property(nonatomic, assign) AVCaptureVideoOrientation currentOrientation;

@property(nonatomic, strong) AVCaptureDevice *currentDevice;

- (void)start:(void(^)(NSError *error))handle;

- (void)stop:(void(^)(NSURL *url, NSError *error))handle;

- (void)writeData:(AVCaptureConnection *)connection
            video:(AVCaptureConnection*)video
            audio:(AVCaptureConnection *)audio
           buffer:(CMSampleBufferRef)buffer;

@end

NS_ASSUME_NONNULL_END
