//
//  CCVideoPreview.m
//  CCCamera
//
//  Created by wsk on 16/8/22.
//  Copyright © 2016年 cyd. All rights reserved.
//

#import "CCVideoPreview.h"

@implementation CCVideoPreview

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [(AVCaptureVideoPreviewLayer *)self.layer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    }
    return self;
}

- (AVCaptureSession*)captureSessionsion {
    return [(AVCaptureVideoPreviewLayer*)self.layer session];
}

- (void)setCaptureSessionsion:(AVCaptureSession *)session {
    [(AVCaptureVideoPreviewLayer*)self.layer setSession:session];
}

// 使该view的layer方法返回AVCaptureVideoPreviewLayer对象
+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

@end
