//
//  ViewController.h
//  硬编码
//
//  Created by 管章鹏 on 2017/12/11.
//  Copyright © 2017年 管章鹏. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VideoCapture : NSObject
    
- (void)startCapturing:(UIView *)preView;
- (void)stopCapturing;

@end
