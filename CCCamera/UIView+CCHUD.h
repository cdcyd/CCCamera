//
//  UIView+CCHUD.h
//  CCCamera
//
//  Created by wsk on 16/8/24.
//  Copyright © 2016年 cyd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (CCHUD)

@property(nonatomic, strong ,readonly)UIAlertController *ccAlertController;

// 加载框
-(void)showHUD:(UIViewController *)vc message:(NSString *)message;      // 没有菊花

-(void)showLoadHUD:(UIViewController *)vc message:(NSString *)message;  // 有菊花

-(void)hideHUD;

// 提示框
-(void)showAutoDismissHUD:(UIViewController *)vc message:(NSString *)message;

-(void)showAutoDismissHUD:(UIViewController *)vc message:(NSString *)message delay:(NSTimeInterval)delay;

// 弹出框
-(void)showAlertView:(UIViewController *)vc message:(NSString *)message sure:(void(^)(UIAlertAction * act))sure cancel:(void(^)(UIAlertAction * act))cancel;

-(void)showAlertView:(UIViewController *)vc title:(NSString *)title message:(NSString *)message sureTitle:(NSString *)sureTitle cancelTitle:(NSString *)cancelTitle sure:(void(^)(UIAlertAction * act))sure cancel:(void(^)(UIAlertAction * act))cancel;

@end
