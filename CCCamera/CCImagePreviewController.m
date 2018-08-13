//
//  CCImagePreviewController.m
//  CCCamera
//
//  Created by wsk on 16/8/22.
//  Copyright © 2016年 cyd. All rights reserved.
//

#import "CCImagePreviewController.h"

@interface CCImagePreviewController ()
{
    UIImage *_image;
    CGRect   _frame;
}
@end

@implementation CCImagePreviewController

- (instancetype)initWithImage:(UIImage *)image frame:(CGRect)frame{
    if (self = [super initWithNibName:nil bundle:nil]) {
        _image = image;
        _frame = frame;
    }
    return self;
}

- (instancetype)init{
    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Use -initWithImage: frame:" userInfo:nil];
}

+ (instancetype)new{
    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Use -initWithImage: frame:" userInfo:nil];
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder{
    return [self initWithImage:nil frame:CGRectZero];
}

-(instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    return [self initWithImage:nil frame:CGRectZero];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIImageView *imageView = [[UIImageView alloc]initWithImage:_image];
    imageView.layer.masksToBounds = YES;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.frame = CGRectMake(0, 0, _frame.size.width, _frame.size.height);
    [self.view addSubview:imageView];
    NSLog(@"%ld--%ld", (long)_image.imageOrientation, UIImageOrientationUp);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
