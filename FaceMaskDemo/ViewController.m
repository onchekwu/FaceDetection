//
//  ViewController.m
//  FaceMaskDemo
//
//  Created by Obi Nchekwube
//  Copyright (c) 2015

#import "ViewController.h"

@implementation ViewController

@synthesize faceDetectionTimer, currentImage, maskImage, shouldUpdateMaskPosition;

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.view setBounds:[UIScreen mainScreen].bounds];
    [self.view setFrame:[UIScreen mainScreen].bounds];
    
    AVCaptureVideoDataOutput *videoDataOutput = [AVCaptureVideoDataOutput new];
    NSDictionary *newSettings = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
    videoDataOutput.videoSettings = newSettings;

    //Discard if the data output queue is blocked during processing the still image)
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [videoDataOutput setSampleBufferDelegate:self queue:(dispatch_queue_t)(videoDataOutputQueue)];
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPresetMedium;
    if ( [session canAddOutput:videoDataOutput] )
        [session addOutput:videoDataOutput];
    
    AVCaptureVideoPreviewLayer* captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    captureVideoPreviewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:captureVideoPreviewLayer];
    
    AVCaptureDevice *device = [self frontFacingCameraIfAvailable];
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        NSLog(@"Error opening camera: %@", error);
    }
    
    [session addInput:input];
    [session startRunning];
    
    AVCaptureConnection *videoConnection = nil;
    for ( AVCaptureConnection *connection in [videoDataOutput connections] )
    {
        for ( AVCaptureInputPort *port in [connection inputPorts] )
        {
            if ( [[port mediaType] isEqual:AVMediaTypeVideo] )
            {
                videoConnection = connection;
            }
        }
    }
    if([videoConnection isVideoOrientationSupported])
    {
        [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }
    
    self.currentImage = [[UIImageView alloc] init];
    self.maskImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"mask.png"]];
    
    UIWindow *mainWindow = [UIApplication sharedApplication].windows[0];
    [mainWindow addSubview:self.maskImage];
    [mainWindow bringSubviewToFront:self.maskImage];
    
    shouldUpdateMaskPosition = YES;
    
    self.faceDetectionTimer = [NSTimer scheduledTimerWithTimeInterval:0.2f
                                                               target:self
                                                             selector:@selector(faceMask)
                                                             userInfo:nil
                                                              repeats:YES];
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    
    if(shouldUpdateMaskPosition) {
        [self.currentImage setImage:[self imageFromSampleBuffer:sampleBuffer]];
        shouldUpdateMaskPosition = NO;
    }
    // Add your code here that uses the image.
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}

-(void)findFaces:(UIImageView*)facePicture
{
    //Create a CIImage from our face picture
    CIImage* image = [CIImage imageWithCGImage:facePicture.image.CGImage];
    
    //Create a face detector. Speed is an issue so use low accuracy.
    NSDictionary* options = [NSDictionary dictionaryWithObject:CIDetectorAccuracyLow
                                                        forKey:CIDetectorAccuracy];
    CIDetector* detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:nil
                                              options:options];
    
    //Create the array containing all the detected faces
    NSArray* features = [detector featuresInImage:image];
    
    UIWindow *mainWindow = [UIApplication sharedApplication].windows[0];
    [mainWindow bringSubviewToFront:self.maskImage];
    
    //Iterate through all the faces found in our current image
    for(CIFaceFeature* faceFeature in features)
    {
        //Set the mask center referencing the last face found
        if(faceFeature.hasMouthPosition)
        {
            CGPoint maskCenter = CGPointMake(faceFeature.mouthPosition.x, faceFeature.mouthPosition.y + 15);
            [self.maskImage setCenter:maskCenter];
        }
    }
}

-(void)faceMask
{
    //This is so we may flip (transform) the view with the video processing wthout issue
    [self.view.layer setNeedsDisplay];
    
    //Flip the UIImage in order to use the CIImage coordinate system
    [self.currentImage setTransform:CGAffineTransformMakeScale(-1, -1)];
    [self.view setTransform:CGAffineTransformMakeScale(-1, -1)];
    [self.maskImage setTransform:CGAffineTransformMakeScale(-1, -1)];
    UIWindow *mainWindow = [UIApplication sharedApplication].windows[0];
    [mainWindow setTransform:CGAffineTransformMakeScale(-1, -1)];
    
    //Run the method to find all the faces in our currentImage
    [self findFaces:self.currentImage];
    
    //Update the boolean to YES so we process the next camera captured still image
    shouldUpdateMaskPosition = YES;
}

-(AVCaptureDevice *)frontFacingCameraIfAvailable
{
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *captureDevice = nil;
    for (AVCaptureDevice *device in videoDevices)
    {
        if (device.position == AVCaptureDevicePositionFront)
        {
            captureDevice = device;
            break;
        }
    }
    //Use the defualt if we can't find a front facing camera
    if ( ! captureDevice)
    {
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    return captureDevice;
}


@end
