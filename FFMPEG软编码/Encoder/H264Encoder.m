//
//  ViewController.m
//  FFMPEG软编码
//
//  Created by 管章鹏 on 2017/12/8.
//  Copyright © 2017年 管章鹏. All rights reserved.
//
/*
 FFMPEG的几个关键的结构体:
 Encode:
 
                   AVInputFormat
 
 AVFormatContext   AVStream[0] -> AVCodecContext -> AVCodec
 
                   AVStream[0] -> AVCodecContext -> AVCodec
 
 Decode:
 
 AVPacket -> AVFrame
 */
#import "H264Encoder.h"
#import "avformat.h"
#import "avcodec.h"

@interface H264Encoder()
{
    AVFormatContext *pFormatCxt;
    AVStream *pStream;
    AVCodecContext *pCodecCtx;
    AVCodec *pCodec;
    AVFrame *pFrame;
    
    int frame_width;
    int frame_height;
    int frame_size;
    AVPacket packet;
}

@end

@implementation H264Encoder

- (void)prepareEncodeWithWidth:(int)width height:(int)height
{
    // 1.注册所有的格式和编码器
    av_register_all();
    
    // 2.创建AVFormatContext
    // 2.1.创建AVFormatContext
    pFormatCxt = avformat_alloc_context();
    
    // 2.2.创建输出流
    NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"123.h264"];
    AVOutputFormat *outputFormat = av_guess_format(NULL, [filePath UTF8String], NULL);
    pFormatCxt->oformat = outputFormat;
    
    // 2.3.打开输出流
    if (avio_open(&pFormatCxt->pb, [filePath UTF8String], AVIO_FLAG_READ_WRITE) < 0) {
        NSLog(@"打开输出流失败");
        return;
    }
    
    // 3.创建AVStream
    // 3.1.创建AVStream
    pStream = avformat_new_stream(pFormatCxt, 0);
    
    // 3.2.设置采样率time_base(用于计算之后pts/dts)
    // num : 分子
    // den : 分母
    // 8000 44100 rtmp 1000
    pStream->time_base.num = 1;
    pStream->time_base.den = 90000;
    
    // 3.3.判断pStream是否有值
    if (pStream == NULL) {
        NSLog(@"创建输出流失败");
        return;
    }
    
    // 4.获取AVCodecContext : 包含编码所有的参数从AVStream
    // 4.1.获取AVCodecContext
    pCodecCtx = pStream->codec;
    
    // 4.2.设置编码的是音频还是视频
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    
    // 4.3.设置编码的标准(h264/h265)
    pCodecCtx->codec_id = AV_CODEC_ID_H264;
    
    // 4.4.设置像素数据的格式(RGB/YUV)
    pCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P;
    
    // 4.5.设置编码视频的宽度和高度
    pCodecCtx->width = width;
    pCodecCtx->height = height;
    
    // 4.6.设置帧率
    pCodecCtx->time_base.num = 24;
    pCodecCtx->time_base.den = 1;
    
    // 4.7.设置比特率
    pCodecCtx->bit_rate = 1500000;
    
    // 4.8.设置GOP
    pCodecCtx->gop_size = 30;
    
    // 4.9.设置最大的联系B帧的数量
    pCodecCtx->max_b_frames = 5;
    
    // 4.10.设置视频的最大质量和最小质量
    pCodecCtx->qmax = 51;
    pCodecCtx->qmin = 10;
    
    // 5.通过AVCodecContext去查找编码器AVCodec
    // 5.1.查找编码器
    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    
    // 5.2.判断编码器是否有找到
    if (pCodec == NULL) {
        NSLog(@"查找编码器失败");
        return;
    }
    
    // 5.3.打开编码器
    AVDictionary *parma = 0;
    if (pCodecCtx->codec_id == AV_CODEC_ID_H264) {
        av_dict_set(&parma, "preset", "slow", 0);
        av_dict_set(&parma, "tune", "zerolatency", 0);
    }
    if (avcodec_open2(pCodecCtx, pCodec, &parma) < 0) {
        NSLog(@"打开编码器失败");
        return;
    }
    
    // 6.创建AVFrame --> AVPakcet
    // 6.1.创建AVFrame
    pFrame = av_frame_alloc();
    
    // 6.2.添加内容
    uint8_t buffer;
    avpicture_fill((AVPicture *)pFrame, &buffer, AV_PIX_FMT_YUV420P, width, height);
    
    // 7.记录宽度和高度
    frame_width = width;
    frame_height = height;
    frame_size = width * height;
}

- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer
{
    // CMSampleBufferRef -> AVFrame --> AVPacket --> 写入文件
    // NV12和NV21属于YUV420格式，是一种two-plane模式，即Y和UV分为两个Plane，但是UV（CbCr）为交错存储，而不是分为三个plane
    // YUV444
    // YUV420: 4 - 1 - 1
    // NV12中Y是一个单独的plane, 而UV是交错存储, 占据一个一个plane
    // 1.获取CVImageBuffer
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // 2.锁定CVImageBufferRef对应的内存地址
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess) {
        // 3.1.获取Y分量的地址
        UInt8 *bufferPtr = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);
        // 3.2.获取UV分量的地址
        UInt8 *bufferPtr1 = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,1);
        
        // 3.3.根据像素获取图片的真实宽度&高度
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        // 获取Y分量每行的数据量
        size_t yBPR = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,0);
        // 获取UV分量每行的数据量
        size_t uvBPR = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,1);
        
        // 4:1:1
        // y分量需要的内存空间: width * height
        // uv分量需要的内存空间: width * height * 1/4 + width * height * 1/4 = 1/2 * width * height
        UInt8 *yuv420_data = (UInt8 *)malloc(width * height * 3 / 2);
        
        // 3.4.将NV12数据转成YUV420的I420数据
        // iOS默认采集的NV12数据 --> I420
        // NV12 4 : 1 : 1  -->  yyyyyyyyyyyy uvuvuv
        // I420 4 : 1 : 1  -->  yyyyyyyyyyyy uuuvvv
        UInt8 *pU = yuv420_data + width*height;
        UInt8 *pV = pU + width*height/4;
        for(int i =0;i<height;i++)
        {
            memcpy(yuv420_data+i*width,bufferPtr+i*yBPR,width);
        }
        
        for(int j = 0;j<height/2;j++)
        {
            for(int i =0;i<width/2;i++)
            {
                *(pU++) = bufferPtr1[i<<1];
                *(pV++) = bufferPtr1[(i<<1) + 1];
            }
            bufferPtr1+=uvBPR;
        }
        
        // 4.将获取到的yuv数据, 传给AVFrame
        // 4.1.将YUV数据传递给pFrame
        pFrame->data[0] = yuv420_data;
        pFrame->data[1] = yuv420_data + width * height;
        pFrame->data[2] = yuv420_data + width * height * 5 / 4;
        
        // 4.2.设置pFrame的宽度和高度
        pFrame->width = frame_width;
        pFrame->height = frame_height;
        
        // 4.3.设置颜色的格式
        pFrame->format = AV_PIX_FMT_YUV420P;
        
        // 5.将AVFrame编码成AVPacket
        // 5.1.进行编码操作
        int got_picture = 0;
        
        if (avcodec_encode_video2(pCodecCtx, &packet, pFrame, &got_picture) < 0) {
            NSLog(@"编码一帧数据失败");
            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
            return;
        }
        
        // 5.2.设置packet属性
        if (got_picture) {
            // 5.3.设置流的下标值
            packet.stream_index = pStream->index;
            
            // 5.3.直接将packet写入文件
            av_write_frame(pFormatCxt, &packet);
            
            // 5.4.清除内存
            av_free_packet(&packet);
        }
        
        free(yuv420_data);
    }
    
    // 3.解锁
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

- (void)endEncoding
{
    av_write_trailer(pFormatCxt);
    
    avcodec_close(pCodecCtx);
    avpicture_free((AVPicture *)pFrame);
    free(pFormatCxt);
}

@end
