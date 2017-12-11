//
//  ViewController.m
//  硬解码
//
//  Created by 管章鹏 on 2017/12/11.
//  Copyright © 2017年 管章鹏. All rights reserved.
//
#import "ViewController.h"
#import <VideoToolbox/VideoToolbox.h>
#import "AAPLEAGLLayer.h"

const char pStartCode[]= "\x00\x00\x00\x01";

@interface ViewController ()
{
    // 读取到的数据
    long inputMaxSize;
    long inputSize;
    uint8_t *inputBuffer;
    
    // 解析的数据
    long packetSize;
    uint8_t *packetBuffer;
    
    long spsSize;
    uint8_t *pSPS;
    
    long ppsSize;
    uint8_t *pPPS;
    
    VTDecompressionSessionRef decompressionSession;
    CMVideoFormatDescriptionRef formatDescription;
}

@property (nonatomic, weak) CADisplayLink *displayLink;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, weak) AAPLEAGLLayer *glLayer;

//@property (nonatomic, assign)
//@property (nonatomic, assign)

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 1.创建CADisplayLink
    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
    self.displayLink = displayLink;
    self.displayLink.frameInterval = 2;
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self.displayLink setPaused:YES];
    
    // 2.创建NSInputStream
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"123.h264" ofType:nil];
    self.inputStream = [NSInputStream inputStreamWithFileAtPath:filePath];
    
    // 3.创建队列
    self.queue = dispatch_get_global_queue(0, 0);
    
    // 4.创建用于渲染的layer
    AAPLEAGLLayer *layer = [[AAPLEAGLLayer alloc] initWithFrame:self.view.bounds];
    [self.view.layer insertSublayer:layer atIndex:0];
    self.glLayer = layer;
}


- (IBAction)play {
    // 1.初始化一次读取多少数据, 以及数据的长度, 数据存放在哪里
    inputMaxSize = 1280 * 720;
    inputSize = 0;
    inputBuffer = malloc(inputMaxSize);
    
    // 2.打开inputStream
    [self.inputStream open];
    
    // 3.开始读取数据
    [self.displayLink setPaused:NO];
}


#pragma mark - 开始读取数据
- (void)updateFrame {
    dispatch_sync(_queue, ^{
        // 1.读取数据
        [self readPacket];
        
        // 2.判断数据的类型
        if (packetSize == 0 && packetBuffer == NULL) {
            [self.displayLink setPaused:YES];
            [self.inputStream close];
            NSLog(@"数据已经读完了");
            return;
        }
        
        // 3.解码 H264大端数 数据是在内存中:系统端数据
        uint32_t nalSize = (uint32_t)(packetSize - 4);
        uint32_t *pNAL = (uint32_t *)packetBuffer;
        *pNAL = CFSwapInt32HostToBig(nalSize);
        
        // 4.获取类型 sps : 0x27 pps: 0x28 IDR : 0x25
        // 00 10 01 11
        // 00 01 11 11
        // 00 00 01 11 == 7
        // 00 10 10 00
        // 前五位: 0x07  sps  0x08  pps  0x05 : i
        // 00 00 00 0A 27
        //
        int nalType = packetBuffer[4] & 0x1F;
        switch (nalType) {
            case 0x07:
                spsSize = packetSize - 4;
                pSPS = malloc(spsSize);
                memcpy(pSPS, packetBuffer + 4, spsSize);
                break;
                
            case 0x08:
                ppsSize = packetSize - 4;
                pPPS = malloc(ppsSize);
                memcpy(pPPS, packetBuffer + 4, ppsSize);
                break;
                
            case 0x05:
                // 1.创建VTDecompressionSessionRef -->  sps/pps --> gop
                [self initDecompressSession];
                
                // 2.解码I帧
                [self decodeFrame];
                break;
                
            default:
                [self decodeFrame];
                break;
        }
    });
}

#pragma mark - 从文件中读取一个NALU的数据
// AVFrame(编码前的帧数据)/AVPacket(编码后的帧数据)
- (void)readPacket {
    // 1.每次读取的时候, 必须保证之前的数据, 清除掉
    if (packetSize || packetBuffer) {
        packetSize = 0;
        free(packetBuffer);
        packetBuffer = nil;
    }
    
    // 2.读取数据
    if (inputSize < inputMaxSize && _inputStream.hasBytesAvailable) {
        inputSize += [self.inputStream read:inputBuffer + inputSize maxLength:inputMaxSize - inputSize];
    }
    // inputSize == inputMaxSize
    
    // 3.获取解码想要的数据 0x 00 00 00 01
    // -1 : 非正常 0 : 正常
    if (memcmp(inputBuffer, pStartCode, 4) == 0) {
        uint8_t *pStart = inputBuffer + 4;
        uint8_t *pEnd = inputBuffer + inputSize;
        while (pStart != pEnd) {
            if (memcmp(pStart - 3, pStartCode, 4) == 0) {
                // 获取到下一个 0x 00 00 00 01
                packetSize = pStart - 3 - inputBuffer;
                
                // 从inputBuffer中, 拷贝数据到, packetBuffer
                packetBuffer = malloc(packetSize);
                memcpy(packetBuffer, inputBuffer, packetSize);
                
                // 将数据, 移动到最前方
                memmove(inputBuffer, inputBuffer + packetSize, inputSize - packetSize);
                
                // 改变inputSize的大小
                inputSize -= packetSize;
                
                break;
            } else {
                pStart++;
            }
        }
    }
}


#pragma mark - 初始化VTDecompressionSession
- (void)initDecompressSession {
    // 1.创建CMVideoFormatDescriptionRef
    const uint8_t *pParamSet[2] = {pSPS, pPPS};
    const size_t pParamSizes[2] = {spsSize, ppsSize};
    CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL, 2, pParamSet, pParamSizes, 4, &formatDescription);
    
    // 2.创建VTVTDecompressionSessionRef YUV(YCrCb)/R
    // 4 : 4 : 4  = 12      three plane
    // 4 : 1 : 1  =  6 YUV420  two plane
    NSDictionary *attrs = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
    VTDecompressionOutputCallbackRecord callbackRecord;
    callbackRecord.decompressionOutputCallback = decodeCallback;
    VTDecompressionSessionCreate(NULL, formatDescription, NULL, (__bridge CFDictionaryRef)attrs, &callbackRecord, &decompressionSession);
}

void decodeCallback(void * CM_NULLABLE decompressionOutputRefCon,
                    void * CM_NULLABLE sourceFrameRefCon,
                    OSStatus status,
                    VTDecodeInfoFlags infoFlags,
                    CM_NULLABLE CVImageBufferRef imageBuffer,
                    CMTime presentationTimeStamp,
                    CMTime presentationDuration ) {
    ViewController *vc = (__bridge ViewController *)sourceFrameRefCon;
    vc.glLayer.pixelBuffer = imageBuffer;
}


#pragma mark - 解码数据
- (void)decodeFrame {
    // SPS/PPS  CMblockBuffer
    // 1. 通过数据创建一个CMblockBuffer
    CMBlockBufferRef blockBuffer;
    CMBlockBufferCreateWithMemoryBlock(NULL, (void *)packetBuffer, packetSize, kCFAllocatorNull, NULL, 0, packetSize, 0, &blockBuffer);
    
    // 2.准备CMSampleBufferRef
    size_t sizeArray[] = {packetSize};
    CMSampleBufferRef sampleBuffer;
    CMSampleBufferCreateReady(NULL, blockBuffer, formatDescription, 0, 0, NULL, 0, sizeArray, &sampleBuffer);
    
    // 3.开始解码操作
    OSStatus status = VTDecompressionSessionDecodeFrame(decompressionSession, sampleBuffer, 0, (__bridge void * _Nullable)(self), NULL);
    if (status == noErr) {
    }
}


@end
