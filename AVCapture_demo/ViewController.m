//
//  ViewController.m
//  AVCapture_demo
//
//  Created by Derek on 21/12/17.
//  Copyright © 2017年 Derek. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

/**
 *  常量类
 */
#define IS_IOS_7 ([[[UIDevice currentDevice] systemVersion] floatValue] >=7.0 ? YES : NO)
#define IS_IOS_8 ([[[UIDevice currentDevice] systemVersion] floatValue] >=8.0 ? YES : NO)
#define IS_IPHONE5 (([[UIScreen mainScreen] bounds].size.height-568)?NO:YES)
#define WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define HEIGHT ([[UIScreen mainScreen] bounds].size.height)
#define START_POSITION ([[[UIDevice currentDevice] systemVersion] floatValue] >=7.0 ? 20 : 0)

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate>
{
    AVCaptureSession *_captureSession;
    UIImageView *_outputImageView;
    AVCaptureVideoPreviewLayer *_captureLayer;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    self.view.backgroundColor = [UIColor whiteColor];
    
    //2. 获取后置摄像头设备对象
    AVCaptureDevice *device = nil;
    //NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if (camera.position == AVCaptureDevicePositionFront) {//取得前置置摄像头
            device = camera;
        }
    }
    if(!device) {
        NSLog(@"取得后置摄像头错误");
        return;
    }
    

    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    //AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] error:nil];//此处打开是调用后置摄像头
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc]init];
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    //captureOutput.minFrameDuration = CMTimeMake(1, 10);
    
    dispatch_queue_t queue;
    queue = dispatch_queue_create("cameraQueue", NULL);
    [captureOutput setSampleBufferDelegate:self queue:queue];
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    [captureOutput setVideoSettings:videoSettings];
    _captureSession = [[AVCaptureSession alloc] init];
    
    //判断分辨率是否支持1280*720，支持就设置为1280*720
    if( [_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720] ) {
        _captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    }
    [_captureSession addInput:captureInput];
    [_captureSession addOutput:captureOutput];
    [_captureSession startRunning];
    
    
    //实时显示摄像头内容
    _captureLayer = [AVCaptureVideoPreviewLayer layerWithSession: _captureSession];
    _captureLayer.frame = CGRectMake(10, START_POSITION+10, WIDTH-20, 200);
    _captureLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer: _captureLayer];
    
    //显示输出图片
    _outputImageView = [[UIImageView alloc]initWithFrame:CGRectMake(10, CGRectGetMaxY(_captureLayer.frame)+10, CGRectGetWidth(_captureLayer.frame), CGRectGetHeight(_captureLayer.frame))];
    [self.view addSubview:_outputImageView];
    
    
    UIButton *stopButton = [[UIButton alloc]initWithFrame:CGRectMake(10, CGRectGetMaxY(_outputImageView.frame)+30, CGRectGetWidth(_outputImageView.frame)/2-10, 50)];
    stopButton.backgroundColor = [UIColor redColor];
    [stopButton setTitle:@"stop" forState:UIControlStateNormal];
    [stopButton setTitle:@"stop" forState:UIControlStateHighlighted];
    [stopButton addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stopButton];
    
    UIButton *startButton = [[UIButton alloc]initWithFrame:CGRectMake(10+CGRectGetWidth(_outputImageView.frame)/2, CGRectGetMaxY(_outputImageView.frame)+30, CGRectGetWidth(_outputImageView.frame)/2-10, 50)];
    startButton.backgroundColor = [UIColor blackColor];
    [startButton setTitle:@"start" forState:UIControlStateNormal];
    [startButton setTitle:@"start" forState:UIControlStateHighlighted];
    [startButton addTarget:self action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startButton];
    
}
#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress,width, height, 8, bytesPerRow, colorSpace,kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image= [UIImage imageWithCGImage:newImage scale:1.0 orientation:UIImageOrientationRight];
    CGImageRelease(newImage);
    [_outputImageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}
-(void)stop{
    [_captureSession stopRunning];
}
-(void)start{
    [_captureSession startRunning];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
