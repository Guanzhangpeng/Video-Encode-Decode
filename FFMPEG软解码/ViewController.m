//
//  ViewController.m
//  FFMPEG软解码
//
//  Created by 管章鹏 on 2017/12/11.
//  Copyright © 2017年 管章鹏. All rights reserved.
//

#import "ViewController.h"
#import "avformat.h"
#import "avcodec.h"
#import "OpenGLView20.h"

@interface ViewController ()
{
    AVFormatContext *pFormatCtx;
    AVStream *pStream;
    AVCodecContext *pCodecCtx;
    AVCodec *pCodec;
    AVFrame *pFrame;
    AVPacket packet;
    int video_index;
}

@property (nonatomic, strong) OpenGLView20 *glView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.glView = [[OpenGLView20 alloc] initWithFrame:self.view.bounds];
    [self.view insertSubview:self.glView atIndex:0];
    
    // 1.注册所有的格式和编码器
    av_register_all();
    
    // 2.获取文件所在的目录
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"story.mp4" ofType:nil];
    if (avformat_open_input(&pFormatCtx, [filePath UTF8String], NULL, NULL) < 0) {
        NSLog(@"打开输入流失败");
        return;
    }
    
    // 3.从AVFormatContext中查找AVStream
    if (avformat_find_stream_info(pFormatCtx, NULL) < 0) {
        NSLog(@"查找AVStream失败");
        return;
    }
    
    // 4.取出AVStream视频流信息
    video_index = -1;
    for (int i = 0; i < pFormatCtx->nb_streams; i++) {
        if (pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            video_index = i;
            break;
        }
    }
    pStream = pFormatCtx->streams[video_index];
    
    // 5.取出解码上下文
    pCodecCtx = pStream->codec;
    
    // 6.查找解码器
    // 6.1.获取解码器
    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    if (pCodec == NULL) {
        NSLog(@"查找解码器失败");
        return;
    }
    
    // 6.2.打开解码器
    if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        NSLog(@"打开解码器失败");
        return;
    }
    
    // 7.创建AVFrame
    pFrame = av_frame_alloc();
}

- (IBAction)playBtnClick:(id)sender {
    while (av_read_frame(pFormatCtx, &packet) >= 0) {
        if (packet.stream_index == video_index) {
            int got_picture = -1;
            if (avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, &packet) < 0) {
                continue;
            }
            
            if (got_picture) {
                // 申请内存空间
                char *buf = (char *)malloc(pFrame->width * pFrame->height * 3 / 2);
                AVPicture *pict = (AVPicture *)pFrame;//这里的frame就是解码出来的AVFrame
                int w, h, i;
                char *y, *u, *v;
                w = pFrame->width;
                h = pFrame->height;
                y = buf;
                u = y + w * h;
                v = u + w * h / 4;
                for (i=0; i<h; i++)
                    memcpy(y + w * i, pict->data[0] + pict->linesize[0] * i, w);
                for (i=0; i<h/2; i++)
                    memcpy(u + w / 2 * i, pict->data[1] + pict->linesize[1] * i, w / 2);
                for (i=0; i<h/2; i++)
                    memcpy(v + w / 2 * i, pict->data[2] + pict->linesize[2] * i, w / 2);
                if (buf == NULL) {
                    continue;
                }else {
                    dispatch_async(dispatch_get_global_queue(0, 0), ^{
                        sleep(1);
                        NSLog(@"-------");
                        [_glView displayYUV420pData:buf width:pFrame -> width height:pFrame ->height];
                        free(buf);
                    });
                }
            }
        }
    }
}


@end
