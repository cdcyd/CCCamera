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

@dynamic ccAlertController;

-(UIAlertController *)ccAlertController{
    NSObject * obj = objc_getAssociatedObject(self, KEY_CC_ALERT_VIEW);
    if (obj && [obj isKindOfClass:[UIAlertController class]]){
        return (UIAlertController *)obj;
    }
    return nil;
}

-(void)setCcAlertController:(UIAlertController *)ccAlertController
{
    if (nil == ccAlertController){
        return;
    }
    objc_setAssociatedObject(self, KEY_CC_ALERT_VIEW, ccAlertController, OBJC_ASSOCIATION_RETAIN_NONATOMIC );
}

#pragma mark - 不会自动消失的提示框
-(void)showHUD:(UIViewController *)vc message:(NSString *)message{
    [self showHUD:vc message:message isLoad:NO];
}

-(void)showLoadHUD:(UIViewController *)vc message:(NSString *)message{
    [self showHUD:vc message:message isLoad:YES];
}

-(void)showHUD:(UIViewController *)vc message:(NSString *)message isLoad:(BOOL)isLoad{
    if (!self.ccAlertController) {
        self.ccAlertController = [UIAlertController alertControllerWithTitle:nil
                                                                     message:[NSString stringWithFormat:@"\n\n\n%@",message]
                                                              preferredStyle:UIAlertControllerStyleAlert];
        if (isLoad) {
            [self findLabel:self.ccAlertController.view succ:^(UIView *label) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
                    activityView.color = [UIColor lightGrayColor];
                    activityView.center = CGPointMake(label.width/2, 25);
                    [label addSubview:activityView];
                    [activityView startAnimating];
                });
            }];
        }
    }
    [vc presentViewController:self.ccAlertController animated:YES completion:nil];
}

#pragma mark - 会自动消失的提示框
-(void)showAutoDismissHUD:(UIViewController *)vc message:(NSString *)message{
    [self showAutoDismissHUD:vc message:message delay:0.3];
}

-(void)showAutoDismissHUD:(UIViewController *)vc message:(NSString *)message delay:(NSTimeInterval)delay{
    if (!self.ccAlertController) {
        self.ccAlertController = [UIAlertController alertControllerWithTitle:nil
                                                                     message:message
                                                              preferredStyle:UIAlertControllerStyleAlert];
        
        UIView *view = [[UIView alloc]initWithFrame:self.ccAlertController.view.bounds];
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityView.center = CGPointMake(view.width/2, view.height/2);
        [view addSubview:activityView];
        
    }
    [vc presentViewController:self.ccAlertController animated:YES completion:nil];
    [NSTimer scheduledTimerWithTimeInterval:delay
                                     target:self
                                   selector:@selector(hideHUD)
                                   userInfo:self.ccAlertController
                                    repeats:NO];
}

-(void)hideHUD{
    if (self.ccAlertController) {
        [self.ccAlertController dismissViewControllerAnimated:YES completion:^{
            
        }];
    }
}

-(void)findLabel:(UIView*)view succ:(void(^)(UIView *label))succ
{
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

@end
