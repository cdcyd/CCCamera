//
//  UILabel+CCFont.m
//  CCCamera
//
//  Created by wsk on 16/8/22.
//  Copyright © 2016年 cyd. All rights reserved.
//

#import "UILabel+CCFont.h"
#import <objc/runtime.h>

#define CustomFontName @"STXingkai"

@implementation UILabel (CCFont)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL systemSel = @selector(willMoveToSuperview:);
        SEL swizzSel = @selector(labelWillMoveToSuperview:);
        
        Method systemMethod = class_getInstanceMethod([self class], systemSel);
        Method swizzMethod = class_getInstanceMethod([self class], swizzSel);
        
        BOOL isAdd = class_addMethod(self, systemSel, method_getImplementation(swizzMethod), method_getTypeEncoding(swizzMethod));
        if (isAdd) {
            class_replaceMethod(self, swizzSel, method_getImplementation(systemMethod), method_getTypeEncoding(systemMethod));
        } 
        else{
            method_exchangeImplementations(systemMethod, swizzMethod);
        }
    });
}

- (void)labelWillMoveToSuperview:(UIView *)newSuperview {
    [self labelWillMoveToSuperview:newSuperview];
    if ([UIFont fontNamesForFamilyName:CustomFontName]){
        self.font  = [UIFont fontWithName:CustomFontName size:[UIFont labelFontSize]];
    }
}

@end
