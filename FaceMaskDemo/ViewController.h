//
//  ViewController.h
//  FaceMaskDemo
//
//  Created by Obi Nchekwube
//  Copyright (c) 2015

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

@interface ViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    NSTimer * faceDetectionTimer;
    UIImageView * currentImage;
    UIImageView * maskImage;
    BOOL shouldUpdateMaskPosition;
}

@property(nonatomic, strong) NSTimer* faceDetectionTimer;
@property(nonatomic, strong) UIImageView * currentImage;
@property(nonatomic, strong) UIImageView * maskImage;
@property(nonatomic) BOOL shouldUpdateMaskPosition;


-(void)findFaces:(UIImageView*)facePicture;
-(void)faceMask;


@end
