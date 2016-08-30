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

-(void)showHUD:(UIViewController *)vc message:(NSString *)message;      // 没有菊花

-(void)showLoadHUD:(UIViewController *)vc message:(NSString *)message;  // 有菊花

-(void)showAutoDismissHUD:(UIViewController *)vc message:(NSString *)message;

-(void)showAutoDismissHUD:(UIViewController *)vc message:(NSString *)message delay:(NSTimeInterval)delay;

-(void)hideHUD;

@end
