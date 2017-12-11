//
//  ViewController.m
//  视频直播中的编码和解码
//
//  Created by 管章鹏 on 2017/12/8.
//  Copyright © 2017年 管章鹏. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (nonatomic, strong) VideoCapture *videoCapture;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}
- (IBAction)startCapturing:(id)sender {
    [self.videoCapture startCapturing:self.view];
}

- (IBAction)stopCapturing:(id)sender {
    [self.videoCapture stopCapturing];
}



@end
