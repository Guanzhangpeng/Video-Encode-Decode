//
//  ViewController.m
//  FFMPEG软编码
//
//  Created by 管章鹏 on 2017/12/8.
//  Copyright © 2017年 管章鹏. All rights reserved.
//

#import "ViewController.h"
#import "VideoCapture.h"

@interface ViewController ()
@property (nonatomic, strong) VideoCapture *videoCapture;
@end

@implementation ViewController


/*
 1> 创建AVCaptureSession
 2> 添加输入设备
 * 摄像头 device -> position
 3> 添加输出
 * AVCaptureDataVideooutput
 * 设置代理
 4> 添加预览图层
 * previewLayer
 5> 开始采集视频
 */

- (VideoCapture *)videoCapture {
    if (!_videoCapture) {
        _videoCapture = [[VideoCapture alloc] init];
    }
    return _videoCapture;
}

- (IBAction)startCapturing:(id)sender {
    [self.videoCapture startCapturing:self.view];
}

- (IBAction)stopCapturing:(id)sender {
    [self.videoCapture stopCapturing];
}


@end
