//
//  CCTools.h
//  CCCamera
//
//  Created by wsk on 16/8/22.
//  Copyright © 2016年 cyd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CCTools : NSObject

+ (void)createGIFfromURL:(NSURL*)videoURL loopCount:(int)loopCount completion:(void(^)(NSURL *GifURL))completionBlock;

+ (void)createGIFfromURL:(NSURL*)videoURL frameCount:(int)frameCount delayTime:(float)delayTime loopCount:(int)loopCount completion:(void(^)(NSURL *GifURL))completionBlock;

@end
