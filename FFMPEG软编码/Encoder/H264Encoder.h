//
//  ViewController.m
//  FFMPEG软编码
//
//  Created by 管章鹏 on 2017/12/8.
//  Copyright © 2017年 管章鹏. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface H264Encoder : NSObject

- (void)prepareEncodeWithWidth:(int)width height:(int)height;
- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer;
- (void)endEncoding;

@end
