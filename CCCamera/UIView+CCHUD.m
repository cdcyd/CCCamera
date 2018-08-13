//
//  UIView+CCHUD.m
//  CCCamera
//
//  Created by wsk on 16/8/24.
//  Copyright © 2016年 cyd. All rights reserved.
//

#import "UIView+CCHUD.h"
#import <objc/runtime.h>

#define KEY_CC_ALERT_VIEW "UIView.AlertController"

@implementation UIView (CCHUD)
@dynamic alertController;

-(UIAlertController *)alertController{
    NSObject * obj = objc_getAssociatedObject(self, KEY_CC_ALERT_VIEW);
    if (obj && [obj isKindOfClass:[UIAlertController class]]){
        return (UIAlertController *)obj;
    }
    return nil;
}

-(void)setAlertController:(UIAlertController *)alertController
{
    if (nil == alertController){ return; }
    objc_setAssociatedObject(self, KEY_CC_ALERT_VIEW, alertController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 加载框
-(void)showHUD:(NSString *)message{
    [self showHUD:message isLoad:NO];
}

-(void)showLoadHUD:(NSString *)message{
    [self showHUD:message isLoad:YES];
}

-(void)showHUD:(NSString *)message isLoad:(BOOL)isLoad{
    UIAlertController *alertController = [self getAVC];
    alertController.message = [NSString stringWithFormat:@"\n\n\n%@", message];
    if (isLoad) {
        [self findLabel:alertController.view succ:^(UIView *label) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
                activityView.color = [UIColor lightGrayColor];
                activityView.center = CGPointMake(label.width/2, 25);
                [label addSubview:activityView];
                [activityView startAnimating];
            });
        }];
    }
    [self.viewController presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - 提示框
-(void)showAutoDismissHUD:(NSString *)message{
    [self showAutoDismissHUD:message delay:0.3];
}

-(void)showAutoDismissHUD:(NSString *)message delay:(NSTimeInterval)delay{
    UIAlertController *alertController = [self getAVC];
    alertController.message = message;
    [self.viewController presentViewController:alertController animated:YES completion:nil];
    [NSTimer scheduledTimerWithTimeInterval:delay
                                     target:self
                                   selector:@selector(hideHUD)
                                   userInfo:alertController
                                    repeats:NO];
}

-(void)hideHUD{
    [[self getAVC] dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 弹出框
- (void)showError:(NSError *)error{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showAlertView:error.localizedDescription ok:^(UIAlertAction *action) {

        } cancel:nil];
    });
}

-(void)showAlertView:(NSString *)message ok:(void(^)(UIAlertAction * action))ok cancel:(void(^)(UIAlertAction * action))cancel{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    if (cancel) {
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            !cancel ? : cancel(action) ;
        }];
        [alertController addAction:cancelAction];
    }
    if (ok) {
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            !ok ? : ok(action) ;
        }];
        [alertController addAction:okAction];
    }
    [self.viewController presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Private methods
-(void)findLabel:(UIView*)view succ:(void(^)(UIView *label))succ{
    for (UIView* subView in view.subviews)
    {
        if ([subView isKindOfClass:[UILabel class]]) {
            if (succ) {
                succ(subView);
            }
        }
        [self findLabel:subView succ:succ];
    }
}

-(UIAlertController *)getAVC{
    if (!self.alertController) {
        self.alertController = [UIAlertController alertControllerWithTitle:nil
                                                                   message:@""
                                                            preferredStyle:UIAlertControllerStyleAlert];
    }
    return self.alertController;
}

@end
