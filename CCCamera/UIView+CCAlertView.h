//
//  UIView+CCAlertView.h
//  CCCamera
//
//  Created by wsk on 16/8/22.
//  Copyright © 2016年 cyd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (CCAlertView)

-(void)showAutoDismissAlert:(UIViewController *)vc message:(NSString *)message;

-(void)showAutoDismissAlert:(UIViewController *)vc message:(NSString *)message delay:(NSTimeInterval)delay;

-(void)showAutoDismissAlert:(UIViewController *)vc message:(NSString *)message delay:(NSTimeInterval)delay complete:(void(^)(void))complete;

-(void)showAlertView:(UIViewController *)vc message:(NSString *)message sure:(void(^)(UIAlertAction * act))sure cancel:(void(^)(UIAlertAction * act))cancel;

-(void)showAlertView:(UIViewController *)vc title:(NSString *)title message:(NSString *)message sureTitle:(NSString *)sureTitle cancelTitle:(NSString *)cancelTitle sure:(void(^)(UIAlertAction * act))sure cancel:(void(^)(UIAlertAction * act))cancel;

@end
