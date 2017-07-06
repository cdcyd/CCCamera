//
//  CCCameraView.h
//  CCCamera
//
//  Created by 佰道聚合 on 2017/7/5.
//  Copyright © 2017年 cyd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CCVideoPreview.h"

@class CCCameraView;
@protocol CCCameraViewDelegate <NSObject>
@optional;

/// 转换摄像头
-(void)swicthCameraAction:(CCCameraView *)cameraView succ:(void(^)(void))succ fail:(void(^)(NSError *error))fail;
/// 自动聚焦曝光
-(void)autoFocusAndExposureAction:(CCCameraView *)cameraView succ:(void(^)(void))succ fail:(void(^)(NSError *error))fail;
/// 补光按钮
-(void)torchLightAction:(CCCameraView *)cameraView succ:(void(^)(void))succ fail:(void(^)(NSError *error))fail;
/// 闪光灯按钮
-(void)flashLightAction:(CCCameraView *)cameraView succ:(void(^)(void))succ fail:(void(^)(NSError *error))fail;
/// 聚焦
-(void)focusAction:(CCCameraView *)cameraView point:(CGPoint)point succ:(void(^)(void))succ fail:(void(^)(NSError *error))fail;
/// 曝光
-(void)exposAction:(CCCameraView *)cameraView point:(CGPoint)point succ:(void(^)(void))succ fail:(void(^)(NSError *error))fail;

/// 取消
-(void)cancelAction:(CCCameraView *)cameraView;
/// 拍照
-(void)takePhotoAction:(CCCameraView *)cameraView;
/// 停止录制视频
-(void)stopRecordVideoAction:(CCCameraView *)cameraView;
/// 开始录制视频
-(void)startRecordVideoAction:(CCCameraView *)cameraView;
/// 改变拍摄类型
-(void)didChangeTypeAction:(CCCameraView *)cameraView type:(NSInteger)type;

@end

@interface CCCameraView : UIView

@property(nonatomic, weak) id <CCCameraViewDelegate> delegate;

@property(nonatomic, strong, readonly) CCVideoPreview *previewView;

@property(nonatomic, assign, readonly) NSInteger type; // 1：拍照 2：视频

-(void)changeTorch:(BOOL)on;

-(void)changeFlash:(BOOL)on;

@end
