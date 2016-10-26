//
//  CCImagePreviewController.h
//  CCCamera
//
//  Created by wsk on 16/8/22.
//  Copyright © 2016年 cyd. All rights reserved.
//

#import "CCBaseViewController.h"

@interface CCImagePreviewController : CCBaseViewController

+ (instancetype)new  NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithImage:(UIImage *)image frame:(CGRect)frame NS_DESIGNATED_INITIALIZER;

@end
