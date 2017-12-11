//
//  ViewController.m
//  FFMPEG软编码
//
//  Created by 管章鹏 on 2017/12/8.
//  Copyright © 2017年 管章鹏. All rights reserved.
//

#import "VideoCapture.h"
#import <AVFoundation/AVFoundation.h>
#import "H264Encoder.h"

@interface VideoCapture() <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, weak) AVCaptureSession *session;
@property (nonatomic, weak) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) H264Encoder *encoder;

@end

@implementation VideoCapture

- (H264Encoder *)encoder {
    if (!_encoder) {
        _encoder = [[H264Encoder alloc] init];
    }
    return _encoder;
}
    
- (void)startCapturing:(UIView *)preView
{
    // 0.准备进行编码
    [self.encoder prepareEncodeWithWidth:480 height:640];
    
    // =============================== 采集视频 =================================
    // 1.创建session
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPreset640x480;
    self.session = session;
    
    // 2.设置视频的输入
    // AVCaptureDevicePosition : 前置/后置
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    [session addInput:input];
    
    // 3.设置视频的输出
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    [output setSampleBufferDelegate:self queue:queue];
    [output setAlwaysDiscardsLateVideoFrames:YES];
    [session addOutput:output];
    output.videoSettings = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
    
    // 视频输出的方向
    // 注意: 设置方向, 必须在将output添加到session之后
    AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
    if (connection.isVideoOrientationSupported) {
        connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    } else {
        NSLog(@"不支持设置方向");
    }
    
    // 4.添加预览图层
    AVCaptureVideoPreviewLayer *layer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    layer.frame = preView.bounds;
    [preView.layer insertSublayer:layer atIndex:0];
    self.previewLayer = layer;
    
    // 5.开始采集
    [session startRunning];
}

- (void)stopCapturing
{
    [self.previewLayer removeFromSuperlayer];
    [self.session stopRunning];
}

// 如果出现丢帧
- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // CMSampleBufferRef -> 一张图像/一帧画面
    [self.encoder encodeFrame:sampleBuffer];
}

@end
