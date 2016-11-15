//
//  CCTools.m
//  CCCamera
//
//  Created by wsk on 16/8/22.
//  Copyright © 2016年 cyd. All rights reserved.
//

#import "CCTools.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>

#define gifFileName  @"gifName.gif"
#define timeInterval @(600)
#define tolerance    @(0.01)

typedef NS_ENUM(NSInteger, GIFSize) {
    GIFSizeVeryLow  = 2,
    GIFSizeLow      = 3,
    GIFSizeMedium   = 5,
    GIFSizeHigh     = 7,
    GIFSizeOriginal = 10
};

@implementation CCTools

+ (void)createGIFfromURL:(NSURL*)videoURL loopCount:(int)loopCount completion:(void(^)(NSURL *GifURL))completionBlock{
    
    // 大小
    AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];
    float videoWidth = [[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize].width;
    float videoHeight = [[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize].height;
    GIFSize optimalSize = GIFSizeMedium;
    if (videoWidth >= 1200 || videoHeight >= 1200){
        optimalSize = GIFSizeVeryLow;
    }
    else if (videoWidth >= 800 || videoHeight >= 800){
        optimalSize = GIFSizeLow;
    }
    else if (videoWidth >= 400 || videoHeight >= 400){
        optimalSize = GIFSizeMedium;
    }
    else if (videoWidth < 400|| videoHeight < 400){
        optimalSize = GIFSizeHigh;
    }
    
    // 每秒取贞的时间点
    float videoLength = (float)asset.duration.value/asset.duration.timescale;
    int framesPerSecond = 4;
    int frameCount = videoLength * framesPerSecond;
    float increment = (float)videoLength / frameCount;
    NSMutableArray *timePoints = [NSMutableArray array];
    for (int currentFrame = 0; currentFrame < frameCount; ++currentFrame) {
        float seconds = (float)increment * currentFrame;
        CMTime time = CMTimeMakeWithSeconds(seconds, [timeInterval intValue]);
        [timePoints addObject:[NSValue valueWithCMTime:time]];
    }
    
    // 循环属性
    NSDictionary *fileProperties = [self filePropertiesWithLoopCount:loopCount];
    
    // 延迟属性
    float delayTime = 0.1f;
    NSDictionary *frameProperties = [self framePropertiesWithDelayTime:delayTime];
    
    dispatch_group_t gifQueue = dispatch_group_create();
    dispatch_group_enter(gifQueue);
    __block NSURL *gifURL;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        gifURL = [self createGIFforTimePoints:timePoints fromURL:videoURL fileProperties:fileProperties frameProperties:frameProperties frameCount:frameCount gifSize:optimalSize];
        dispatch_group_leave(gifQueue);
    });
    
    dispatch_group_notify(gifQueue, dispatch_get_main_queue(), ^{
        completionBlock(gifURL);
    });
}

+ (void)createGIFfromURL:(NSURL*)videoURL frameCount:(int)frameCount delayTime:(float)delayTime loopCount:(int)loopCount completion:(void(^)(NSURL *GifURL))completionBlock{
    // 循环属性
    NSDictionary *fileProperties = [self filePropertiesWithLoopCount:loopCount];
    
    // 延迟属性
    NSDictionary *frameProperties = [self framePropertiesWithDelayTime:delayTime];
    
    // 大小
    AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];
    float videoLength = (float)asset.duration.value/asset.duration.timescale;
    float increment = (float)videoLength/frameCount;
    NSMutableArray *timePoints = [NSMutableArray array];
    for (int currentFrame = 0; currentFrame<frameCount; ++currentFrame) {
        float seconds = (float)increment * currentFrame;
        CMTime time = CMTimeMakeWithSeconds(seconds, [timeInterval intValue]);
        [timePoints addObject:[NSValue valueWithCMTime:time]];
    }
    
    dispatch_group_t gifQueue = dispatch_group_create();
    dispatch_group_enter(gifQueue);
    __block NSURL *gifURL;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        gifURL = [self createGIFforTimePoints:timePoints fromURL:videoURL fileProperties:fileProperties frameProperties:frameProperties frameCount:frameCount gifSize:GIFSizeMedium];
        dispatch_group_leave(gifQueue);
    });
    
    dispatch_group_notify(gifQueue, dispatch_get_main_queue(), ^{
        completionBlock(gifURL);
    });
}

#pragma mark - Base methods
+ (NSURL *)createGIFforTimePoints:(NSArray *)timePoints fromURL:(NSURL *)url fileProperties:(NSDictionary *)fileProperties frameProperties:(NSDictionary *)frameProperties frameCount:(int)frameCount gifSize:(GIFSize)gifSize{
    
    NSString *temporaryFile = [NSTemporaryDirectory() stringByAppendingString:gifFileName];
    NSURL *fileURL = [NSURL fileURLWithPath:temporaryFile];
    if (fileURL == nil) return nil;
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)fileURL, kUTTypeGIF , frameCount, NULL);
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    
    CMTime tol = CMTimeMakeWithSeconds([tolerance floatValue], [timeInterval intValue]);
    generator.requestedTimeToleranceBefore = tol;
    generator.requestedTimeToleranceAfter = tol;
    
    NSError *error = nil;
    CGImageRef previousImageRefCopy = nil;
    for (NSValue *time in timePoints) {
        
        CGImageRef imageRef;
        if ((float)gifSize/10 != 1) {
            imageRef = createImageWithScale([generator copyCGImageAtTime:[time CMTimeValue] actualTime:nil error:&error], (float)gifSize/10);
        }
        else{
            imageRef = [generator copyCGImageAtTime:[time CMTimeValue] actualTime:nil error:&error];
        }
        if (error) {
            NSLog(@"Error copying image: %@", error);
        }
        
        if (imageRef) {
            CGImageRelease(previousImageRefCopy);
            previousImageRefCopy = CGImageCreateCopy(imageRef);
        } 
        else if (previousImageRefCopy) {
            imageRef = CGImageCreateCopy(previousImageRefCopy);
        } 
        else {
            NSLog(@"Error copying image and no previous frames to duplicate");
            return nil;
        }
        CGImageDestinationAddImage(destination, imageRef, (CFDictionaryRef)frameProperties);
        CGImageRelease(imageRef);
    }
    CGImageRelease(previousImageRefCopy);
    
    CGImageDestinationSetProperties(destination, (CFDictionaryRef)fileProperties);
    if (!CGImageDestinationFinalize(destination)) {
        NSLog(@"Failed to finalize GIF destination: %@", error);
        if (destination != nil) {
            CFRelease(destination);
        }
        return nil;
    }
    CFRelease(destination);
    return fileURL;
}

#pragma mark - Helpers
CGImageRef createImageWithScale(CGImageRef imageRef, float scale) {
    
    CGSize newSize = CGSizeMake(CGImageGetWidth(imageRef)*scale, CGImageGetHeight(imageRef)*scale);
    CGRect newRect = CGRectIntegral(CGRectMake(0, 0, newSize.width, newSize.height));
    
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return nil;
    
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, newSize.height);
    
    CGContextConcatCTM(context, flipVertical);
    CGContextDrawImage(context, newRect, imageRef);
    CFRelease(imageRef);
    
    imageRef = CGBitmapContextCreateImage(context);
    UIGraphicsEndImageContext();
    
    return imageRef;
}

#pragma mark - Properties
+ (NSDictionary *)filePropertiesWithLoopCount:(int)loopCount {
    return @{(NSString *)kCGImagePropertyGIFDictionary:@{(NSString *)kCGImagePropertyGIFLoopCount:@(loopCount)}};
}

+ (NSDictionary *)framePropertiesWithDelayTime:(float)delayTime {
    return @{(NSString *)kCGImagePropertyGIFDictionary:@{(NSString *)kCGImagePropertyGIFDelayTime:@(delayTime)},
             (NSString *)kCGImagePropertyColorModel:(NSString *)kCGImagePropertyColorModelRGB};
}

@end
