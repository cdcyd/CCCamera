//
//  CCCameraViewController.m
//  CCCamera
//
//  Created by wsk on 16/8/22.
//  Copyright © 2016年 cyd. All rights reserved.
//

#import "CCCameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import <CoreMedia/CMMetadata.h>
#import <GLKit/GLKit.h>

#import "CCVideoPreview.h"
#import "CCImagePreviewController.h"
#import "CCTools+GIF.h"
#import "UIView+CCHUD.h"
#import "CCMotionManager.h"

@interface CCCameraViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>
{
    AVCaptureSession            *_captureSession;
    
    // 输入
    AVCaptureDeviceInput        *_deviceInput;
        
    // 输出
    AVCaptureConnection         *_videoConnection;
    AVCaptureConnection         *_audioConnection;
    AVCaptureVideoDataOutput    *_videoOutput;
    AVCaptureStillImageOutput   *_imageOutput;
    
    // 写入
    NSURL						*_movieURL;
    AVAssetWriter               *_assetWriter;
    AVAssetWriterInput			*_assetAudioInput;
    AVAssetWriterInput          *_assetVideoInput;
    
    dispatch_queue_t             _movieWritingQueue;
    BOOL						 _readyToRecordVideo;
    BOOL						 _readyToRecordAudio;
    BOOL                         _recording;
}

// 相机设置
@property(nonatomic, strong) AVCaptureDevice *activeCamera;     // 当前输入设备
@property(nonatomic, strong) AVCaptureDevice *inactiveCamera;   // 不活跃的设备(这里指前摄像头或后摄像头，不包括外接输入设备)
@property(nonatomic) AVCaptureTorchMode torchMode;
@property(nonatomic) AVCaptureFlashMode flashMode;

// UI
@property(nonatomic, strong) CCVideoPreview *previewView;
@property(nonatomic, strong) UIView   *bottomView;
@property(nonatomic, strong) UIView   *topView;
@property(nonatomic, strong) UIView   *focusView;   // 聚焦动画
@property(nonatomic, strong) UIView   *exposureView;// 曝光动画
@property(nonatomic, strong) UIButton *photoBtn;
@property(nonatomic, strong) UIButton *typeBtn;
@property(nonatomic, strong) UIButton *torchBtn;
@property(nonatomic, strong) UIButton *flashBtn;
@property(nonatomic, assign) BOOL      isGIF;  //拍照片还是GIF

// 设备方向
@property(nonatomic, strong) CCMotionManager   *motionManager;
@property(readwrite) AVCaptureVideoOrientation	referenceOrientation; // 视频播放方向

@end

@implementation CCCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    
    _movieURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"movie.mov"]];
    _referenceOrientation = AVCaptureVideoOrientationPortrait;
    _motionManager = [[CCMotionManager alloc] init];
    
    NSError *error;
    [self setupSession:&error];
    if (!error) {
        [self.previewView setCaptureSessionsion:_captureSession];
        [self startCaptureSession];
    }
    else{
        [self showError:error];
    }
}

#pragma mark - AVCaptureSession life cycle
- (void)setupSession:(NSError **)error{
    _captureSession = [[AVCaptureSession alloc]init];
    [_captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    
    [self setupSessionInputs:error];
    [self setupSessionOutputs:error];
}

- (void)setupSessionInputs:(NSError **)error{
    // 视频输入
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:error];
    if (videoInput) {
        if ([_captureSession canAddInput:videoInput]){
            [_captureSession addInput:videoInput];
            _deviceInput = videoInput;
        }
    }
    
    // 音频输入
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioIn = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:error];
    if ([_captureSession canAddInput:audioIn]){
        [_captureSession addInput:audioIn];
    }
}

- (void)setupSessionOutputs:(NSError **)error{
    dispatch_queue_t captureQueue = dispatch_queue_create("com.cc.MovieCaptureQueue", DISPATCH_QUEUE_SERIAL);
    // 音频输出
    AVCaptureAudioDataOutput *audioOut = [[AVCaptureAudioDataOutput alloc] init];
    [audioOut setSampleBufferDelegate:self queue:captureQueue];
    if ([_captureSession canAddOutput:audioOut]){
        [_captureSession addOutput:audioOut];
    }
    _audioConnection = [audioOut connectionWithMediaType:AVMediaTypeAudio];
    
    // 视频输出
    AVCaptureVideoDataOutput *videoOut = [[AVCaptureVideoDataOutput alloc] init];
    [videoOut setAlwaysDiscardsLateVideoFrames:YES];
    [videoOut setVideoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]}];
    [videoOut setSampleBufferDelegate:self queue:captureQueue];
    if ([_captureSession canAddOutput:videoOut]){
        [_captureSession addOutput:videoOut];
        _videoOutput = videoOut;
    }
    _videoConnection = [videoOut connectionWithMediaType:AVMediaTypeVideo];
    _videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    // 静态图片输出
    AVCaptureStillImageOutput *imageOutput = [[AVCaptureStillImageOutput alloc] init];            
    imageOutput.outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    if ([_captureSession canAddOutput:imageOutput]) {
        [_captureSession addOutput:imageOutput];
        _imageOutput = imageOutput;
    }
}

// 开启捕捉
- (void)startCaptureSession
{
    if (!_movieWritingQueue) {
        _movieWritingQueue = dispatch_queue_create("Movie Writing Queue", DISPATCH_QUEUE_SERIAL);
    }
    
    if (!_captureSession.isRunning){
        [_captureSession startRunning];
    }
}

// 停止捕捉
- (void)stopCaptureSession
{
    if (_captureSession.isRunning){
        [_captureSession stopRunning];
    }
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = NO;
}

#pragma mark - 录制视频
// 开始录制
- (void)startRecording
{
    dispatch_async(_movieWritingQueue, ^{
        [self removeFile:_movieURL];
        if (!_assetWriter) {
            NSError *error;
            _assetWriter = [[AVAssetWriter alloc] initWithURL:_movieURL fileType:AVFileTypeQuickTimeMovie error:&error];
            if (error){
                [self showError:error];
            }
        }
        _recording = YES;
    });
}

// 停止录制
- (void)stopRecording
{
    // 录制完成后 要马上停止视频捕捉 否则写入相册会失败
    [self stopCaptureSession];
    _recording = NO;
    
    dispatch_async(_movieWritingQueue, ^{
        [_assetWriter finishWritingWithCompletionHandler:^(){
            
            // 重新开启会话
            [self startCaptureSession];
            
            AVAssetWriterStatus completionStatus = _assetWriter.status;
            switch (completionStatus)
            {
                case AVAssetWriterStatusCompleted:
                {
                    _readyToRecordVideo = NO;
                    _readyToRecordAudio = NO;
                    _assetWriter = nil;
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [self.view showAlertView:self message:@"是否保存到相册，点确定将保存2个文件到相册，一个视频，一个GIF动图(由于苹果相册不支持查看GIF，所以只有通过QQ等软件查看)" sure:^(UIAlertAction *act) {
                            [self saveMovieToCameraRoll];
                        } cancel:^(UIAlertAction *act) {
                
                        }];
                    });
                    break;
                }
                case AVAssetWriterStatusFailed:
                {
                    [self showError:_assetWriter.error];
                    break;
                }
                default:
                    break;
            }
        }];
    });
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    if (_recording) {
        CFRetain(sampleBuffer);
        dispatch_async(_movieWritingQueue, ^{
            if (_assetWriter)
            {
                if (connection == _videoConnection)
                {
                    if (!_readyToRecordVideo){
                        _readyToRecordVideo = [self setupAssetWriterVideoInput:CMSampleBufferGetFormatDescription(sampleBuffer)];
                    }
                    
                    if ([self inputsReadyToRecord]){
                        [self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeVideo];
                    }
                }
                else if (connection == _audioConnection){
                    if (!_readyToRecordAudio){
                        _readyToRecordAudio = [self setupAssetWriterAudioInput:CMSampleBufferGetFormatDescription(sampleBuffer)];
                    }
                    
                    if ([self inputsReadyToRecord]){
                        [self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeAudio];
                    }
                }
            }
            CFRelease(sampleBuffer);
        });
    }
}

- (BOOL)inputsReadyToRecord
{
    return (_readyToRecordAudio && _readyToRecordVideo);
}


- (void)writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType
{
    if (_assetWriter.status == AVAssetWriterStatusUnknown)
    {
        if ([_assetWriter startWriting]){
            [_assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
        }
        else{
            [self showError:_assetWriter.error];
        }
    }
    
    if (_assetWriter.status == AVAssetWriterStatusWriting)
    {
        if (mediaType == AVMediaTypeVideo)
        {
            if (_assetVideoInput.readyForMoreMediaData)
            {
                if (![_assetVideoInput appendSampleBuffer:sampleBuffer]){
                    [self showError:_assetWriter.error];
                }
            }
        }
        else if (mediaType == AVMediaTypeAudio){
            if (_assetAudioInput.readyForMoreMediaData)
            {
                if (![_assetAudioInput appendSampleBuffer:sampleBuffer]){
                    [self showError:_assetWriter.error];
                }
            }
        }
    }
}

// 配置音频输入
- (BOOL)setupAssetWriterAudioInput:(CMFormatDescriptionRef)currentFormatDescription
{
    size_t aclSize = 0;
    const AudioStreamBasicDescription *currentASBD = CMAudioFormatDescriptionGetStreamBasicDescription(currentFormatDescription);
    const AudioChannelLayout *currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(currentFormatDescription, &aclSize);
    
    NSData *currentChannelLayoutData = nil;
    if (currentChannelLayout && aclSize > 0 ){
        currentChannelLayoutData = [NSData dataWithBytes:currentChannelLayout length:aclSize];
    }
    else{
        currentChannelLayoutData = [NSData data];
    }
        
    NSDictionary *audioCompressionSettings = @{AVFormatIDKey : [NSNumber numberWithInteger:kAudioFormatMPEG4AAC],
                                               AVSampleRateKey : [NSNumber numberWithFloat:currentASBD->mSampleRate],
                                               AVEncoderBitRatePerChannelKey : [NSNumber numberWithInt:64000],
                                               AVNumberOfChannelsKey : [NSNumber numberWithInteger:currentASBD->mChannelsPerFrame],
                                               AVChannelLayoutKey : currentChannelLayoutData};
    
    if ([_assetWriter canApplyOutputSettings:audioCompressionSettings forMediaType:AVMediaTypeAudio])
    {
        _assetAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSettings];
        _assetAudioInput.expectsMediaDataInRealTime = YES;
        
        if ([_assetWriter canAddInput:_assetAudioInput]){
            [_assetWriter addInput:_assetAudioInput];
        }
        else{
            [self showError:_assetWriter.error];
            return NO;
        }
    }
    else{
        [self showError:_assetWriter.error];
        return NO;
    }
    
    return YES;
}

// 配置视频输入
- (BOOL)setupAssetWriterVideoInput:(CMFormatDescriptionRef)currentFormatDescription
{
    CGFloat bitsPerPixel;
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(currentFormatDescription);
    NSUInteger numPixels = dimensions.width * dimensions.height;
    NSUInteger bitsPerSecond;
    
    if (numPixels < (640 * 480)){
        bitsPerPixel = 4.05;
    }
    else{
        bitsPerPixel = 11.4;
    }
    
    bitsPerSecond = numPixels * bitsPerPixel;
    NSDictionary *videoCompressionSettings = @{AVVideoCodecKey  : AVVideoCodecH264,
                                               AVVideoWidthKey  : [NSNumber numberWithInteger:dimensions.width],
                                               AVVideoHeightKey : [NSNumber numberWithInteger:dimensions.height],
                                               AVVideoCompressionPropertiesKey:@{AVVideoAverageBitRateKey:[NSNumber numberWithInteger:bitsPerSecond],
                                                                                 AVVideoMaxKeyFrameIntervalKey:[NSNumber numberWithInteger:30]}
                                               };
    if ([_assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo])
    {
        _assetVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
        _assetVideoInput.expectsMediaDataInRealTime = YES;
        _assetVideoInput.transform = [self transformFromCurrentVideoOrientationToOrientation:self.referenceOrientation];
        if ([_assetWriter canAddInput:_assetVideoInput]){
            [_assetWriter addInput:_assetVideoInput];
        }
        else{
            [self showError:_assetWriter.error];
            return NO;
        }
    }
    else{
        [self showError:_assetWriter.error];
        return NO;
    }
    return YES;
}

// 旋转视频方向
- (CGAffineTransform)transformFromCurrentVideoOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
    CGFloat orientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:orientation];
    CGFloat videoOrientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:self.motionManager.videoOrientation];
    
    CGFloat angleOffset;
    if ([self activeCamera].position == AVCaptureDevicePositionBack) {
        angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
    }
    else{
        angleOffset = videoOrientationAngleOffset - orientationAngleOffset + M_PI_2;
    }
    CGAffineTransform transform = CGAffineTransformMakeRotation(angleOffset);
    return transform;
}

- (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
    CGFloat angle = 0.0;
    switch (orientation)
    {
        case AVCaptureVideoOrientationPortrait:
            angle = 0.0;
            break;
        case AVCaptureVideoOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
        case AVCaptureVideoOrientationLandscapeRight:
            angle = -M_PI_2;
            break;
        case AVCaptureVideoOrientationLandscapeLeft:
            angle = M_PI_2;
            break;
        default:
            break;
    }
    return angle;
}

- (void)saveMovieToCameraRoll
{
    [self.view showLoadHUD:self message:@"保存中..."];
    [CCTools createGIFfromURL:_movieURL loopCount:0 completion:^(NSURL *GifURL) {
        BOOL isSaveGif = YES;
        if (!GifURL) {
            NSLog(@"生成GIF失败");
            isSaveGif = NO;
        }
        
#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_9_0 
        ALAssetsLibrary *lab = [[ALAssetsLibrary alloc]init];
        
        if (isSaveGif) {
            // 保存GIF
            NSData *data = [[NSData alloc]initWithContentsOfURL:GifURL];
            [lab writeImageDataToSavedPhotosAlbum:data metadata:nil completionBlock:^(NSURL *assetURL, NSError *error) {
                [self.view hideHUD];
                if (error) {
                    [self showError:error];
                }
            }];
        }
        
        // 保存视频
        [lab writeVideoAtPathToSavedPhotosAlbum:_movieURL completionBlock:^(NSURL *assetURL, NSError *error) {
            [self.view hideHUD];
            if (error) {
                [self showError:error];
            }
        }];
        
#else
        [PHPhotoLibrary requestAuthorization:^( PHAuthorizationStatus status ) {
            if (status == PHAuthorizationStatusAuthorized) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    
                    if (isSaveGif) {
                        // 保存GIF
                        NSData *data = [[NSData alloc]initWithContentsOfURL:GifURL];
                        PHAssetCreationRequest *gifRequest = [PHAssetCreationRequest creationRequestForAsset];
                        [gifRequest addResourceWithType:PHAssetResourceTypePhoto data:data options:nil];
                    }
                    
                
                    // 保存视频
                    PHAssetCreationRequest *videoRequest = [PHAssetCreationRequest creationRequestForAsset];
                    [videoRequest addResourceWithType:PHAssetResourceTypeVideo fileURL:_movieURL options:nil];
                    
                } completionHandler:^( BOOL success, NSError * _Nullable error ) {
                    [self.view hideHUD];
                    if (!success) {
                        [self showError:error];
                    }
                }];
            }
        }];
#endif
    }];
}

#pragma mark - 捕捉设备
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position { 
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {                              
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

- (AVCaptureDevice *)activeCamera {                                         
    return _deviceInput.device;
}

- (AVCaptureDevice *)inactiveCamera {                                       
    AVCaptureDevice *device = nil;
    if ([[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 1) {
        if ([self activeCamera].position == AVCaptureDevicePositionBack) {  
            device = [self cameraWithPosition:AVCaptureDevicePositionFront];
        } 
        else{
            device = [self cameraWithPosition:AVCaptureDevicePositionBack];
        }
    }
    return device;
}

#pragma mark - 转换前后摄像头
- (void)switchCameraButtonClick:(UIButton *)btn{
    if ([self switchCameras]) {
        btn.selected = !btn.selected;
    }
}

- (BOOL)canSwitchCameras {                                                  
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 1;
}

- (BOOL)switchCameras{
    if (![self canSwitchCameras]) {                                         
        return NO;
    }
    NSError *error;
    AVCaptureDevice *videoDevice = [self inactiveCamera];                   
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if (videoInput) {
        [_captureSession beginConfiguration];                           
        [_captureSession removeInput:_deviceInput];            
        if ([_captureSession canAddInput:videoInput]) {                 
            [_captureSession addInput:videoInput];
            _deviceInput = videoInput;
        } 
        else{
            [_captureSession addInput:_deviceInput];
        }
        [_captureSession commitConfiguration];     
        
        [self resetupVideoOutput];
    } 
    else{
        [self showError:error];          
        return NO;
    }
    return YES;
}


-(void)resetupVideoOutput{
    [_captureSession beginConfiguration]; 
    [_captureSession removeOutput:_videoOutput];
    
    AVCaptureVideoDataOutput *videoOut = [[AVCaptureVideoDataOutput alloc] init];
    [videoOut setAlwaysDiscardsLateVideoFrames:YES];
    [videoOut setVideoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]}];
    dispatch_queue_t videoCaptureQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
    [videoOut setSampleBufferDelegate:self queue:videoCaptureQueue];
    
    if ([_captureSession canAddOutput:videoOut]) {
        [_captureSession addOutput:videoOut];
        _videoOutput = videoOut;
    }
    _videoConnection = [videoOut connectionWithMediaType:AVMediaTypeVideo];
    _videoConnection.videoOrientation = self.referenceOrientation;
    [_captureSession commitConfiguration];
}

#pragma mark - 聚焦
-(void)tapAction:(UIGestureRecognizer *)tap{
    if ([self cameraSupportsTapToFocus]) {
        CGPoint point = [tap locationInView:self.previewView];
        [self runFocusAnimation:self.focusView point:point];
        
        CGPoint focusPoint = [self captureDevicePointForPoint:point];
        [self focusAtPoint:focusPoint];
    }
}

- (BOOL)cameraSupportsTapToFocus {                                          
    return [[self activeCamera] isFocusPointOfInterestSupported];
}

- (void)focusAtPoint:(CGPoint)point {                                       
    AVCaptureDevice *device = [self activeCamera];
    if ([self cameraSupportsTapToFocus] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {                         
            device.focusPointOfInterest = point;
            device.focusMode = AVCaptureFocusModeAutoFocus;
            [device unlockForConfiguration];
        } 
        else{
            [self showError:error];
        }
    }
}

#pragma mark - 曝光
-(void)doubleTapAction:(UIGestureRecognizer *)tap{
    if ([self cameraSupportsTapToExpose]) {
        CGPoint point = [tap locationInView:self.previewView];
        [self runFocusAnimation:self.exposureView point:point];
        
        CGPoint exposePoint = [self captureDevicePointForPoint:point];
        [self exposeAtPoint:exposePoint];
    }
}

- (BOOL)cameraSupportsTapToExpose {                                         
    return [[self activeCamera] isExposurePointOfInterestSupported];
}

static const NSString *CameraAdjustingExposureContext;
- (void)exposeAtPoint:(CGPoint)point{
    AVCaptureDevice *device = [self activeCamera];
    if ([self cameraSupportsTapToExpose] && [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {                         
            device.exposurePointOfInterest = point;
            device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
            if ([device isExposureModeSupported:AVCaptureExposureModeLocked]) {
                [device addObserver:self                                    
                         forKeyPath:@"adjustingExposure"
                            options:NSKeyValueObservingOptionNew
                            context:&CameraAdjustingExposureContext];
            }
            [device unlockForConfiguration];
        } 
        else{
            [self showError:error];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &CameraAdjustingExposureContext) {                     
        AVCaptureDevice *device = (AVCaptureDevice *)object;
        if (!device.isAdjustingExposure && [device isExposureModeSupported:AVCaptureExposureModeLocked]) {
            [object removeObserver:self                                     
                        forKeyPath:@"adjustingExposure"
                           context:&CameraAdjustingExposureContext];
            dispatch_async(dispatch_get_main_queue(), ^{                    
                NSError *error;
                if ([device lockForConfiguration:&error]) {
                    device.exposureMode = AVCaptureExposureModeLocked;
                    [device unlockForConfiguration];
                } 
                else{
                    [self showError:error];
                }
            });
        }
    } 
    else{
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

#pragma mark - 自动聚焦、曝光
-(void)focusAndExposureButtonClick:(UIButton *)btn{
    if ([self resetFocusAndExposureModes]) {
        [self.view showAutoDismissAlert:self message:@"自动聚焦、曝光设置成功!"];
        [self runResetAnimation];
    }
}

- (BOOL)resetFocusAndExposureModes{
    AVCaptureDevice *device = [self activeCamera];
    AVCaptureExposureMode exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    AVCaptureFocusMode focusMode = AVCaptureFocusModeContinuousAutoFocus;
    BOOL canResetFocus = [device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode];
    BOOL canResetExposure = [device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode];
    CGPoint centerPoint = CGPointMake(0.5f, 0.5f);                          
    NSError *error;
    if ([device lockForConfiguration:&error]) {
        if (canResetFocus) {                                                
            device.focusMode = focusMode;
            device.focusPointOfInterest = centerPoint;
        }
        if (canResetExposure) {                                             
            device.exposureMode = exposureMode;
            device.exposurePointOfInterest = centerPoint;
        }
        [device unlockForConfiguration];
        return YES;
    } 
    else{
        [self showError:error];
        return NO;
    }
}

#pragma mark - 闪光灯
-(void)flashClick:(UIButton *)btn{
    if ([self cameraHasFlash]) {
        btn.selected = !btn.selected;
        if ([self flashMode] == AVCaptureFlashModeOff) {
            self.flashMode = AVCaptureFlashModeOn;
        }
        else if ([self flashMode] == AVCaptureFlashModeOn) {
            self.flashMode = AVCaptureFlashModeOff;
        }
    } 
}

- (BOOL)cameraHasFlash {
    return [[self activeCamera] hasFlash];
}

- (AVCaptureFlashMode)flashMode{
    return [[self activeCamera] flashMode];
}

- (void)setFlashMode:(AVCaptureFlashMode)flashMode{
    
    // 如果手电筒打开，先关闭手电筒
    if ([self torchMode] == AVCaptureTorchModeOn) {
        [self torchClick:_torchBtn];
    }
    
    AVCaptureDevice *device = [self activeCamera];
    if (device.flashMode != flashMode && [device isFlashModeSupported:flashMode]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.flashMode = flashMode;
            [device unlockForConfiguration];
        } 
        else{
            [self showError:error];
        }
    }
}

#pragma mark - 手电筒
- (void)torchClick:(UIButton *)btn{
    if ([self cameraHasTorch]) {
        btn.selected = !btn.selected;
        if ([self torchMode] == AVCaptureTorchModeOff) {
            self.torchMode = AVCaptureTorchModeOn;
        }
        else if ([self torchMode] == AVCaptureTorchModeOn) {
            self.torchMode = AVCaptureTorchModeOff;
        }
    }
}

- (BOOL)cameraHasTorch {
    return [[self activeCamera] hasTorch];
}

- (AVCaptureTorchMode)torchMode {
    return [[self activeCamera] torchMode];
}

- (void)setTorchMode:(AVCaptureTorchMode)torchMode{
    
    // 如果闪光灯打开，先关闭闪光灯
    if ([self flashMode] == AVCaptureFlashModeOn) {
        [self flashClick:_flashBtn];
    }
    
    AVCaptureDevice *device = [self activeCamera];
    if (device.torchMode != torchMode && [device isTorchModeSupported:torchMode]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.torchMode = torchMode;
            [device unlockForConfiguration];
        } 
        else{
            [self showError:error];
        }
    }
}

#pragma mark - 取消拍照
- (void)cancel:(UIButton *)btn{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - 转换拍摄类型
- (void)changePhotoType:(UIButton *)btn{
    btn.selected = !btn.selected;
    if (btn.selected) {
        _isGIF = YES;
        [_photoBtn setTitle:@"开始" forState:UIControlStateNormal];
    }
    else{
        _isGIF = NO;
        [_photoBtn setTitle:@"拍照" forState:UIControlStateNormal];
        [self startCaptureSession];
    }
}

#pragma mark - 开始拍照/录影
- (void)takePicture:(UIButton *)btn{
    if (_isGIF){
        if (!_recording) {
            [self startRecording];
            self.topView.userInteractionEnabled = NO;
            self.typeBtn.userInteractionEnabled = NO;
            [_photoBtn setTitle:@"停止" forState:UIControlStateNormal];
        }
        else{
            [self stopRecording];
            self.topView.userInteractionEnabled = YES;
            self.typeBtn.userInteractionEnabled = YES;
            [_photoBtn setTitle:@"开始" forState:UIControlStateNormal];
        }
    }
    else{
        [self takePictureImage];
    }
}

// 拍照
-(void)takePictureImage{
    AVCaptureConnection *connection = [_imageOutput connectionWithMediaType:AVMediaTypeVideo];
    if (connection.isVideoOrientationSupported) {
        connection.videoOrientation = [self currentVideoOrientation];
    }
    id takePictureSuccess = ^(CMSampleBufferRef sampleBuffer,NSError *error){
        if (sampleBuffer == NULL) {
            [self showError:error];
            return ;
        }
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:sampleBuffer];
        UIImage *image = [[UIImage alloc]initWithData:imageData];
        CCImagePreviewController *vc = [[CCImagePreviewController alloc]initWithImage:image previewFrame:self.previewView.frame];
        [self.navigationController pushViewController:vc animated:YES];
    };
    [_imageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:takePictureSuccess];
}

// 调整设备取向
- (AVCaptureVideoOrientation)currentVideoOrientation{
    AVCaptureVideoOrientation orientation;
    switch (self.motionManager.deviceOrientation) { 
        case UIDeviceOrientationPortrait:
            orientation = AVCaptureVideoOrientationPortrait;
            NSLog(@"UIDeviceOrientationPortrait");
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            NSLog(@"UIDeviceOrientationLandscapeRight");
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            NSLog(@"UIDeviceOrientationPortraitUpsideDown");
            break;
        default:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            NSLog(@"AVCaptureVideoOrientationLandscapeRight");
            break;
    }
    return orientation;
}

#pragma mark - 动画
// 聚焦、曝光动画
-(void)runFocusAnimation:(UIView *)view point:(CGPoint)point{
    view.center = point;
    view.hidden = NO;
    [UIView animateWithDuration:0.15f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        view.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0);
    }completion:^(BOOL complete) {
        double delayInSeconds = 0.5f;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            view.hidden = YES;
            view.transform = CGAffineTransformIdentity;
        });
    }];
}

// 自动聚焦、曝光动画
- (void)runResetAnimation {
    self.focusView.center = CGPointMake(self.previewView.width/2, self.previewView.height/2);
    self.exposureView.center = CGPointMake(self.previewView.width/2, self.previewView.height/2);;
    self.exposureView.transform = CGAffineTransformMakeScale(1.2f, 1.2f);
    self.focusView.hidden = NO;
    self.focusView.hidden = NO;
    [UIView animateWithDuration:0.15f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.focusView.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0);
        self.exposureView.layer.transform = CATransform3DMakeScale(0.7, 0.7, 1.0);
    }completion:^(BOOL complete) {
        double delayInSeconds = 0.5f;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            self.focusView.hidden = YES;
            self.exposureView.hidden = YES;
            self.focusView.transform = CGAffineTransformIdentity;
            self.exposureView.transform = CGAffineTransformIdentity;
        });
    }];
}

#pragma mark - Tools
// 将屏幕坐标系的点转换为摄像头坐标系的点
- (CGPoint)captureDevicePointForPoint:(CGPoint)point {                      
    AVCaptureVideoPreviewLayer *layer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
    return [layer captureDevicePointOfInterestForPoint:point];
}

// 移除文件
- (void)removeFile:(NSURL *)fileURL
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = fileURL.path;
    if ([fileManager fileExistsAtPath:filePath])
    {
        NSError *error;
        BOOL success = [fileManager removeItemAtPath:filePath error:&error];
        if (!success){
            [self showError:error];
        }
        else{
            NSLog(@"删除视频文件成功");
        }
    }
}

// 展示错误
- (void)showError:(NSError *)error
{
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void){
        [self.view showAlertView:self title:error.localizedDescription message:error.localizedFailureReason sureTitle:@"确定" cancelTitle:nil sure:nil cancel:nil];
    });
}

#pragma mark - UI
- (void)setupUI{
    self.previewView = [[CCVideoPreview alloc]initWithFrame:CGRectMake(0, 64, CD_SCREEN_WIDTH, CD_SCREEN_HEIGHT-64-100)];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapAction:)];
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTapAction:)];
    doubleTap.numberOfTapsRequired = 2;
    
    [self.previewView addGestureRecognizer:tap];
    [self.previewView addGestureRecognizer:doubleTap];
    [tap requireGestureRecognizerToFail:doubleTap];
    
    [self.view addSubview:self.previewView];
    [self.view addSubview:self.topView];
    [self.view addSubview:self.bottomView];
    [self.previewView addSubview:self.focusView];
    [self.previewView addSubview:self.exposureView];
    
    // 拍照
    UIButton *photoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [photoButton setTitle:@"拍照" forState:UIControlStateNormal];
    [photoButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [photoButton addTarget:self action:@selector(takePicture:) forControlEvents:UIControlEventTouchUpInside];
    [photoButton sizeToFit];
    photoButton.center = CGPointMake(_bottomView.centerX-20, _bottomView.height/2);
    [self.bottomView addSubview:photoButton];
    _photoBtn = photoButton;
    
    // 取消
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancel:) forControlEvents:UIControlEventTouchUpInside];
    [cancelButton sizeToFit];
    cancelButton.center = CGPointMake(40, _bottomView.height/2);
    [self.bottomView addSubview:cancelButton];
    
    // 照片类型
    UIButton *typeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [typeButton setTitle:@"[照片]" forState:UIControlStateNormal];
    [typeButton setTitle:@"[视频]" forState:UIControlStateSelected];
    [typeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [typeButton addTarget:self action:@selector(changePhotoType:) forControlEvents:UIControlEventTouchUpInside];
    [typeButton sizeToFit];
    typeButton.center = CGPointMake(_bottomView.width-60, _bottomView.height/2);
    [self.bottomView addSubview:typeButton];
    _typeBtn = typeButton;
    
    // 转换前后摄像头
    UIButton *switchCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [switchCameraButton setTitle:@"转换摄像头" forState:UIControlStateNormal];
    [switchCameraButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [switchCameraButton setTitleColor:[UIColor blueColor] forState:UIControlStateHighlighted];
    [switchCameraButton addTarget:self action:@selector(switchCameraButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [switchCameraButton sizeToFit];
    switchCameraButton.center = CGPointMake(switchCameraButton.width/2+10, _topView.height/2);
    [self.topView addSubview:switchCameraButton];
    
    // 补光
    UIButton *lightButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [lightButton setTitle:@"补光" forState:UIControlStateNormal];
    [lightButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [lightButton setTitleColor:[UIColor blueColor] forState:UIControlStateSelected];
    [lightButton addTarget:self action:@selector(torchClick:) forControlEvents:UIControlEventTouchUpInside];
    [lightButton sizeToFit];
    lightButton.center = CGPointMake(lightButton.width/2 + switchCameraButton.right+10, _topView.height/2);
    [self.topView addSubview:lightButton];
    _torchBtn = lightButton;
    
    // 闪光灯
    UIButton *flashButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [flashButton setTitle:@"闪光灯" forState:UIControlStateNormal];
    [flashButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [flashButton setTitleColor:[UIColor blueColor] forState:UIControlStateSelected];
    [flashButton addTarget:self action:@selector(flashClick:) forControlEvents:UIControlEventTouchUpInside];
    [flashButton sizeToFit];
    flashButton.center = CGPointMake(flashButton.width/2 + lightButton.right+10, _topView.height/2);
    [self.topView addSubview:flashButton];
    _flashBtn = flashButton;
    
    // 重置对焦、曝光
    UIButton *focusAndExposureButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [focusAndExposureButton setTitle:@"自动聚焦/曝光" forState:UIControlStateNormal];
    [focusAndExposureButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [focusAndExposureButton setTitleColor:[UIColor blueColor] forState:UIControlStateHighlighted];
    [focusAndExposureButton addTarget:self action:@selector(focusAndExposureButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [focusAndExposureButton sizeToFit];
    focusAndExposureButton.center = CGPointMake(focusAndExposureButton.width/2 + flashButton.right+10, _topView.height/2);
    [self.topView addSubview:focusAndExposureButton];
}       

-(UIView *)topView{
    if (_topView == nil) {
        _topView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, CD_SCREEN_WIDTH, 64)];
        _topView.backgroundColor = [UIColor blackColor];
    }
    return _topView;
}

-(UIView *)bottomView{
    if (_bottomView == nil) {
        _bottomView = [[UIView alloc]initWithFrame:CGRectMake(0, CD_SCREEN_HEIGHT - 100, CD_SCREEN_WIDTH, 100)];
        _bottomView.backgroundColor = [UIColor blackColor];
    }
    return _bottomView;
}

-(UIView *)focusView{
    if (_focusView == nil) {
        _focusView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 150, 150.0f)];
        _focusView.backgroundColor = [UIColor clearColor];
        _focusView.layer.borderColor = [UIColor blueColor].CGColor;
        _focusView.layer.borderWidth = 5.0f;
        _focusView.hidden = YES;
    }
    return _focusView;
}

-(UIView *)exposureView{
    if (_exposureView == nil) {
        _exposureView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 150, 150.0f)];
        _exposureView.backgroundColor = [UIColor clearColor];
        _exposureView.layer.borderColor = [UIColor purpleColor].CGColor;
        _exposureView.layer.borderWidth = 5.0f;
        _exposureView.hidden = YES;
    }
    return _exposureView;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
