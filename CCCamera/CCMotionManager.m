//
//  CCMotionManager.m
//  CCCamera
//
//  Created by wsk on 16/8/29.
//  Copyright © 2016年 cyd. All rights reserved.
//

#import "CCMotionManager.h"
#import <CoreMotion/CoreMotion.h>

@interface CCMotionManager() 

@property(nonatomic, strong) CMMotionManager * motionManager;

@end

@implementation CCMotionManager

-(instancetype)init
{
    self = [super init];
    if (self) {
        if (_motionManager == nil) {
            _motionManager = [[CMMotionManager alloc] init];
        }
        _motionManager.deviceMotionUpdateInterval = 1/15.0;
        if (_motionManager.deviceMotionAvailable) {
            NSLog(@"开始陀螺仪");
            [_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue]
                                                withHandler: ^(CMDeviceMotion *motion, NSError *error){
                                                    [self performSelectorOnMainThread:@selector(handleDeviceMotion:) withObject:motion waitUntilDone:YES];
                                                }];
        } 
        else {
            NSLog(@"开启陀螺仪失败");
            [self setMotionManager:nil];
        }
    }
    return self;
}

- (void)handleDeviceMotion:(CMDeviceMotion *)deviceMotion{
    double x = deviceMotion.gravity.x;
    double y = deviceMotion.gravity.y;
    if (fabs(y) >= fabs(x))
    {
        if (y >= 0){
            _deviceOrientation = UIDeviceOrientationPortraitUpsideDown;
            _videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
        }
        else{
            _deviceOrientation = UIDeviceOrientationPortrait;
            _videoOrientation = AVCaptureVideoOrientationPortrait;
        }
    }
    else{
        if (x >= 0){
            _deviceOrientation = UIDeviceOrientationLandscapeRight;
            _videoOrientation = AVCaptureVideoOrientationLandscapeRight;
        }
        else{
            _deviceOrientation = UIDeviceOrientationLandscapeLeft;
            _videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
        }
    }
}

-(void)dealloc{
    [_motionManager stopDeviceMotionUpdates];
}

@end
