//
//  ViewController.h
//  硬编码
//
//  Created by 管章鹏 on 2017/12/11.
//  Copyright © 2017年 管章鹏. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface H264Encoder : NSObject

- (void)prepareEncodeWithWidth:(int)width height:(int)height;
- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer;

- (void)endEncode;

@end
