//
//  UIView+CCAlertView.m
//  CCCamera
//
//  Created by wsk on 16/8/22.
//  Copyright © 2016年 cyd. All rights reserved.
//

#import "UIView+CCAlertView.h"

@implementation UIView (CCAlertView)

#pragma mark - 会自动消失提示框
-(void)showAutoDismissAlert:(UIViewController *)vc message:(NSString *)message{
    [self showAutoDismissAlert:vc message:message delay:0.5f];
}

-(void)showAutoDismissAlert:(UIViewController *)vc message:(NSString *)message delay:(NSTimeInterval)delay{
    [self showAutoDismissAlert:vc message:message delay:delay complete:nil];
}

static void(^completeBlock)(void);
-(void)showAutoDismissAlert:(UIViewController *)vc message:(NSString *)message delay:(NSTimeInterval)delay complete:(void(^)(void))complete{
    completeBlock = complete;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@""
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [vc presentViewController:alertController animated:YES completion:nil];
    [NSTimer scheduledTimerWithTimeInterval:delay
                                     target:self
                                   selector:@selector(autoDismiss:)
                                   userInfo:alertController
                                    repeats:NO];
}

- (void)autoDismiss:(NSTimer *)timer
{
    UIAlertController *alertController = [timer userInfo];
    BOOL result = [self isCurrentViewControllerVisible:alertController];
    if (!result){
        alertController = nil;
        return;
    }
    [alertController dismissViewControllerAnimated:YES completion:^{
        if (completeBlock) {
            completeBlock();
        }
    }];
    alertController = nil;
}

//判断是不是当前显示的控制器
- (BOOL)isCurrentViewControllerVisible:(UIViewController *)VC
{
    return (VC.isViewLoaded && VC.view.window);
}

#pragma mark - 不会自动消失的提示框
-(void)showAlertView:(UIViewController *)vc message:(NSString *)message sure:(void(^)(UIAlertAction * act))sure cancel:(void(^)(UIAlertAction * act))cancel{
    [self showAlertView:vc title:@"提示" message:message sureTitle:@"确定" cancelTitle:@"取消" sure:sure cancel:cancel];
}

-(void)showAlertView:(UIViewController *)vc title:(NSString *)title message:(NSString *)message sureTitle:(NSString *)sureTitle cancelTitle:(NSString *)cancelTitle sure:(void(^)(UIAlertAction * act))sure cancel:(void(^)(UIAlertAction * act))cancel{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    if (cancelTitle) {
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            if (cancel) {
                cancel(action);
            }
        }];
        [alertController addAction:cancelAction];
    }
    
    if (sureTitle) {
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:sureTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (sure) {
                sure(action);
            }
        }];
        [alertController addAction:okAction];
    }
    
    [vc presentViewController:alertController animated:YES completion:nil];
}

@end
