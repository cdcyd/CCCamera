//
//  UIView+CCHUD.h
//  CCCamera
//
//  Created by wsk on 16/8/24.
//  Copyright © 2016年 cyd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (CCHUD)

@property(nonatomic, strong ,readonly)UIAlertController *alertController;

// 加载框
-(void)showHUD:(NSString *)message;      // 没有菊花

-(void)showLoadHUD:(NSString *)message;  // 有菊花

-(void)hideHUD;

// 提示框
-(void)showAutoDismissHUD:(NSString *)message;

-(void)showAutoDismissHUD:(NSString *)message delay:(NSTimeInterval)delay;

// 弹出框
-(void)showError:(NSError *)error;

-(void)showAlertView:(NSString *)message ok:(void(^)(UIAlertAction * action))ok cancel:(void(^)(UIAlertAction * action))cancel;

@end
