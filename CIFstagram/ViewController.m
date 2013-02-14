//
//  ViewController.m
//  CIFstagram
//
//  Created by Tom Harrington on 2/12/13.
//  Copyright (c) 2013 Tom Harrington. All rights reserved.
//

#import "ViewController.h"

#define RAND_IN_RANGE(low,high) (low + (high - low) * (arc4random_uniform(RAND_MAX) / (double)RAND_MAX))

static const NSUInteger thumbnailSize = 100;
static const NSUInteger thumbnailPadding = 20;

@interface ViewController () <UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) UIImagePickerController *imagePickerController;
@property (nonatomic, strong) UIPopoverController *imagePickerPopoverController;
@property (nonatomic, strong) UIImage *currentUIImage;
@property (nonatomic, strong) UIImage *currentFilteredUIImage;
@property (nonatomic, strong) CIImage *currentCIImage;
@property (nonatomic, strong) UIImage *currentThumbnailUIImage;
@property (nonatomic, strong) CIImage *currentThumbnailCIImage;

@property (readwrite, strong) CIContext *ciContext;
@property (nonatomic, strong) NSMutableArray *imageFilters;
@property (nonatomic, strong) NSMutableArray *filterButtons;

@property (nonatomic, assign) CGFloat filterRadiusFactor;
@property (nonatomic, assign) CGFloat filterCenterFactor;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    CIContext *context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer : @NO}];
    [self setCiContext:context];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions
- (IBAction)enhance:(id)sender {
    NSArray *autoAdjustmentFilters = [[self currentCIImage] autoAdjustmentFilters];
    CIImage *enhancedImage = [self currentCIImage];
    for (CIFilter *filter in autoAdjustmentFilters) {
        [filter setValue:enhancedImage forKey:@"inputImage"];
        enhancedImage = [filter outputImage];
    }
    [self applySpecifiedFilter:[autoAdjustmentFilters lastObject]];
}

- (IBAction)faceZoom:(id)sender {
    NSDictionary *detectorOptions = @{CIDetectorAccuracy : CIDetectorAccuracyLow};
    CIDetector *faceDetector = [CIDetector
                                detectorOfType:CIDetectorTypeFace
                                context:nil
                                options:detectorOptions];
    
    NSArray *faces = [faceDetector featuresInImage:[self currentCIImage]
                                           options:nil];
    
    if ([faces count] > 0) {
        CGRect faceZoomRect = CGRectNull;
        
        for (CIFaceFeature *face in faces) {
            if (CGRectEqualToRect(faceZoomRect, CGRectNull)) {
                faceZoomRect = [face bounds];
            } else {
                faceZoomRect = CGRectUnion(faceZoomRect, [face bounds]);
            }
        }
        
        faceZoomRect = CGRectIntersection([[self currentCIImage] extent],
                                          CGRectInset(faceZoomRect, -50.0, -50.0));
        
        CIFilter *cropFilter = [CIFilter filterWithName:@"CICrop"];
        [cropFilter setValue:[self currentCIImage] forKey:@"inputImage"];
        [cropFilter setValue:[CIVector
                              vectorWithCGRect:faceZoomRect]
                      forKey:@"inputRectangle"];
        
        [self applySpecifiedFilter:cropFilter];
    } else {
        UIAlertView *noFacesAlert = [[UIAlertView alloc]
                                     initWithTitle:@"No Faces"
                                     message:@"Sorry, I couldn't find any faces in this picture."
                                     delegate:nil
                                     cancelButtonTitle:@"OK"
                                     otherButtonTitles:nil];
        [noFacesAlert show];
    }
}

- (IBAction)save:(id)sender {
    UIImageWriteToSavedPhotosAlbum([self currentFilteredUIImage], nil, NULL, NULL);
    [[self saveButton] setEnabled:NO];
}

- (IBAction)cancel:(id)sender {
    [[self imageView] setImage:[self currentUIImage]];
    [[self cancelButton] setEnabled:NO];
    [[self saveButton] setEnabled:NO];
}

- (IBAction)getPicture:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
    [actionSheet setDelegate:self];
    [actionSheet addButtonWithTitle:@"Choose from Library"];
    BOOL hasCamera = [UIImagePickerController
                      isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    if (hasCamera) {
        [actionSheet addButtonWithTitle:@"Take Photo"];
    }
    [actionSheet showFromBarButtonItem:[self pictureButton] animated:YES];
}

- (IBAction)applyFilter:(id)sender
{
    CIFilter *filter = [[self imageFilters] objectAtIndex:[sender tag]];
    CIImage *inputCIImage = [self currentCIImage];
    [filter setValue:inputCIImage forKey:@"inputImage"];
    
    [self applySpecifiedFilter:filter];
}

#pragma mark - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // Do nothing if the user taps outside the action
    // sheet (thus closing the popover containing the
    // action sheet).
    if (buttonIndex < 0) {
        return;
    }
    
    if (buttonIndex == 0) {
        // Get from library
        [self presentPhotoLibrary];
    } else if (buttonIndex == 1) {
        // Use camera
        [self presentCamera];
    }
}

#pragma mark - Image acquisition helpers
- (void)presentCamera
{
    // Display the camera.
    UIImagePickerController *imagePicker = [self imagePickerController];
    [imagePicker setSourceType:UIImagePickerControllerSourceTypeCamera];
    [self presentViewController:imagePicker animated:YES completion:nil];
}

- (void)presentPhotoLibrary
{
    // Display assets from the photo library only.
    UIImagePickerController *imagePicker = [self imagePickerController];
    [imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    
    UIPopoverController *newPopoverController =
    [[UIPopoverController alloc] initWithContentViewController:imagePicker];
    [newPopoverController presentPopoverFromBarButtonItem:[self pictureButton]
                                 permittedArrowDirections:UIPopoverArrowDirectionAny
                                                 animated:YES];
    [self setImagePickerPopoverController:newPopoverController];
}

- (UIImagePickerController *)imagePickerController
{
    if (_imagePickerController) {
        return _imagePickerController;
    }
    
    UIImagePickerController *imagePickerController =  nil;
    imagePickerController = [[UIImagePickerController alloc] init];
    [imagePickerController setDelegate:self];
    [self setImagePickerController:imagePickerController];
    
    return _imagePickerController;
}

#pragma mark - UIImagePickerControllerDelegate methods
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    // If the popover controller is available,
    // assume the photo is selected from the library
    // and not from the camera.
    BOOL takenWithCamera = ([self imagePickerPopoverController] == nil);
    
    if (takenWithCamera) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [[self imagePickerPopoverController] dismissPopoverAnimated:YES];
        [self setImagePickerPopoverController:nil];
    }
    
    // Retrieve and display the image.
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    [self setCurrentUIImage:image];
    [[self imageView] setImage:image];
    
    CIImage *ciImage = [CIImage imageWithCGImage:[image CGImage]];
    [self setCurrentCIImage:ciImage];
    CIImage *thumbnailCIImage = [self thumbnailImageForImage:ciImage];
    CGImageRef thumbnailCGImage = [[self ciContext] createCGImage:thumbnailCIImage fromRect:[thumbnailCIImage extent]];
    UIImage *thumbnailImage = [UIImage imageWithCGImage:thumbnailCGImage];
    [self setCurrentThumbnailUIImage:thumbnailImage];
    
    [self randomizeFilters];
    [[self enhanceButton] setEnabled:YES];
    [[self faceZoomButton] setEnabled:YES];
}

- (CIImage *)thumbnailImageForImage:(CIImage *)fullSizeImage
{
    CIFilter *thumbnailScaleFilter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
    [thumbnailScaleFilter setValue:fullSizeImage forKey:@"inputImage"];
    
    CGRect fullSize = [fullSizeImage extent];
    CGFloat scale = MIN(thumbnailSize/fullSize.size.width, thumbnailSize/fullSize.size.height);
    [thumbnailScaleFilter setValue:[NSNumber numberWithFloat:scale] forKey:@"inputScale"];
    
    CIImage *thumbnailImage = [thumbnailScaleFilter outputImage];
    return thumbnailImage;
}

#pragma mark - Filter management
- (void)randomizeFilters
{
    [self setImageFilters:[NSMutableArray array]];
    [self setFilterButtons:[NSMutableArray array]];
    
    // Hue adjust filter
    CIFilter *hueAdjustFilter = [self hueAdjustFilter];
    [[self imageFilters] addObject:hueAdjustFilter];
    
    // Invert color filter
    CIFilter *invertFilter = [self invertColorFilter];
    [[self imageFilters] addObject:invertFilter];
    
    // Affine tile filter
    CIFilter *affineTileFilter = [self affineTileFilter];
    [[self imageFilters] addObject:affineTileFilter];
    
    // Posterize filter
    CIFilter *posterizeFilter = [self posterizeFilter];
    [[self imageFilters] addObject:posterizeFilter];
    
    // Bump distort filter
    CIFilter *bumpDistortFilter = [self bumpDistortionFilter];
    [[self imageFilters] addObject:bumpDistortFilter];
    
    // Twirl distort filter
    CIFilter *twirlDistortFilter = [self twirlFilter];
    [[self imageFilters] addObject:twirlDistortFilter];
    
    // Circle splash filter
    CIFilter *circleSplashDistortionFilter = [self circleSplashDistortionFilter];
    [[self imageFilters] addObject:circleSplashDistortionFilter];
    
    CIFilter *sepiaToneFilter = [self sepiaToneFilter];
    [[self imageFilters] addObject:sepiaToneFilter];
    
    CIFilter *colorTintFilter = [self colorTintFilter];
    [[self imageFilters] addObject:colorTintFilter];
    
    CIFilter *falseColorFilter = [self falseColorFilter];
    [[self imageFilters] addObject:falseColorFilter];
    
    CIFilter *pixellateFilter = [self pixellateFilter];
    [[self imageFilters] addObject:pixellateFilter];
    
    CIImage *thumbnailCIImage = [CIImage imageWithCGImage:[[self currentThumbnailUIImage] CGImage]];
    
    CGRect extents = [thumbnailCIImage extent];
    
    [self setFilterCenterFactor:RAND_IN_RANGE(0.1, 0.9)];
    [self setFilterRadiusFactor:RAND_IN_RANGE(0.1, 0.9)];
    
    for (int i=0; i<[[self imageFilters] count]; i++) {
        CIFilter *filter = [[self imageFilters] objectAtIndex:i];
        [filter setValue:thumbnailCIImage forKey:@"inputImage"];
        
        if ([[filter attributes] objectForKey:@"inputRadius"] != nil) {
            NSNumber *radius = @(extents.size.width * [self filterRadiusFactor]);
            [filter setValue:radius forKey:@"inputRadius"];
        }
        if ([[filter attributes] objectForKey:@"inputCenter"] != nil) {
            CGPoint fCenter;
            fCenter.x = (extents.size.width * [self filterCenterFactor]);
            fCenter.y = (extents.size.height * [self filterCenterFactor]);
            
            CIVector *inputCenter = [CIVector vectorWithX:fCenter.x Y:fCenter.y];
            [filter setValue:inputCenter forKey:@"inputCenter"];
        }
        CIImage *filterResult = [filter outputImage];
        
        CGImageRef filteredCGImage = [[self ciContext]
                                      createCGImage:filterResult
                                      fromRect:[thumbnailCIImage extent]];
        UIImage *filteredImage = [UIImage imageWithCGImage:filteredCGImage];
        CFRelease(filteredCGImage);
        
        UIButton *filterButton = [[UIButton alloc] initWithFrame:CGRectMake(i*(thumbnailSize+thumbnailPadding) + thumbnailPadding, thumbnailPadding, 100, 100)];
        [filterButton addTarget:self action:@selector(applyFilter:) forControlEvents:UIControlEventTouchUpInside];
        [[self filterButtons] addObject:filterButton];
        [[self scrollView] addSubview:filterButton];
        [filterButton setTag:i];
        [filterButton setImage:filteredImage
                      forState:UIControlStateNormal];
    }
    [[self scrollView] setContentSize:CGSizeMake((thumbnailSize+2*thumbnailPadding)*([[self imageFilters] count]-1), [[self scrollView] frame].size.height)];
}

- (void)applySpecifiedFilter:(CIFilter *)filter
{
    CIImage *inputCIImage = [self currentCIImage];
    
    // Set input radius or center, where needed.
    CGRect inputExtents = [inputCIImage extent];
    if ([[filter attributes] objectForKey:@"inputRadius"] != nil) {
        NSNumber *radius = @(inputExtents.size.width * [self filterRadiusFactor]);
        [filter setValue:radius forKey:@"inputRadius"];
    }
    if ([[filter attributes] objectForKey:@"inputCenter"] != nil) {
        CGPoint fCenter;
        fCenter.x = (inputExtents.size.width * [self filterCenterFactor]);
        fCenter.y = (inputExtents.size.height * [self filterCenterFactor]);
        
        CIVector *inputCenter = [CIVector vectorWithX:fCenter.x Y:fCenter.y];
        [filter setValue:inputCenter forKey:@"inputCenter"];
    }
    
    CIImage *filteredCIIImage = [filter outputImage];
    
    // Make sure we're not trying to use infinite extent to create an image
    CGRect cgImageRect;
    if (!CGRectIsInfinite([filteredCIIImage extent])) {
        cgImageRect = [filteredCIIImage extent];
    } else {
        cgImageRect = inputExtents;
    }
    CGImageRef filteredCGImage = [[self ciContext]
                                       createCGImage:filteredCIIImage
                                       fromRect:cgImageRect];
    
    // Convert the result to a UIImage, display it, and save it for later.
    UIImage *filteredImage = [UIImage imageWithCGImage:filteredCGImage];
    CFRelease(filteredCGImage);
    
    [self setCurrentFilteredUIImage:filteredImage];
    [[self imageView] setImage:filteredImage];
    [[self cancelButton] setEnabled:YES];
    [[self saveButton] setEnabled:YES];
}

#pragma mark - Filter methods
- (CIFilter *)hueAdjustFilter
{
    CIFilter *filter = [CIFilter filterWithName:@"CIHueAdjust"];
    CGFloat inputAngle = RAND_IN_RANGE(-M_PI, M_PI);
    [filter setValue:@(inputAngle) forKey:@"inputAngle"];
    return filter;
}

- (CIFilter *)invertColorFilter
{
    CIFilter *filter = [CIFilter filterWithName:@"CIColorInvert"];
    return filter;
}

- (CIFilter *)affineTileFilter
{
    CGFloat scaleFactor = RAND_IN_RANGE(0.2, 0.8);
    CGAffineTransform transform = CGAffineTransformMakeScale(scaleFactor,
                                                             scaleFactor);
    transform = CGAffineTransformRotate(transform,
                                        RAND_IN_RANGE(0.2, M_PI/2));
    
    CIFilter *filter = [CIFilter filterWithName:@"CIAffineTile"];
    [filter setValue:[NSValue valueWithBytes:&transform
                                    objCType:@encode(CGAffineTransform)]
              forKey:@"inputTransform"];
    return filter;
}

- (CIFilter *)posterizeFilter
{
    CIFilter *filter = [CIFilter filterWithName:@"CIColorPosterize"];
    CGFloat posterizeLevel = RAND_IN_RANGE(2.0, 30.0);
    [filter setValue:@(posterizeLevel) forKey:@"inputLevels"];
    
    return filter;
}

- (CIFilter *)bumpDistortionFilter
{
    CIFilter *filter = [CIFilter filterWithName:@"CIBumpDistortion"];
    [filter setValue:@(RAND_IN_RANGE(-1.0, 1.0)) forKey:@"inputScale"];
    return filter;
}

- (CIFilter *)twirlFilter
{
    CIFilter *filter = [CIFilter filterWithName:@"CITwirlDistortion"];
    [filter setValue:@(RAND_IN_RANGE(-M_PI, M_PI)) forKey:@"inputAngle"];
    return filter;
}

- (CIFilter *)circleSplashDistortionFilter
{
    CIFilter *filter = [CIFilter
                        filterWithName:@"CICircleSplashDistortion"];
    return filter;
}

- (CIFilter *)sepiaToneFilter
{
    CIFilter *sepiaFilter = [CIFilter filterWithName:@"CISepiaTone"];
    [sepiaFilter setValue:@(RAND_IN_RANGE(0.1, 0.9)) forKey:@"inputIntensity"];
    return sepiaFilter;
}

- (CIFilter *)colorTintFilter
{
	CIColor *tintColor = [self randomCIColor];
	CIFilter *monochromeFilter = [CIFilter filterWithName:@"CIColorMonochrome"];
	[monochromeFilter setValue:tintColor forKey:@"inputColor"];
    return monochromeFilter;
}

- (CIFilter *)falseColorFilter
{
	CIColor *color0 = [self randomCIColor];
	CIColor *color1 = [CIColor colorWithRed:(1.0 - [color0 red])
									  green:(1.0 - [color0 green])
									   blue:(1.0 - [color0 blue])];
	
	CIFilter *falseColorFilter = [CIFilter filterWithName:@"CIFalseColor"];
	[falseColorFilter setValue:color0 forKey:@"inputColor0"];
	[falseColorFilter setValue:color1 forKey:@"inputColor1"];
    return falseColorFilter;
}

- (CIFilter *)pixellateFilter
{
    CIFilter *filter = [CIFilter filterWithName:@"CIPixellate"];
    [filter setValue:[NSNumber numberWithFloat:20.0] forKey:@"inputScale"];
    return filter;
}

#pragma mark - Color creation
- (CIColor *)randomCIColor
{
	CIColor *randomColor = [CIColor colorWithRed:RAND_IN_RANGE(0.0, 1.0)
										   green:RAND_IN_RANGE(0.0, 1.0)
											blue:RAND_IN_RANGE(0.0, 1.0)];
	return randomColor;
}

- (CIColor *)randomCIColorAlpha
{
	CIColor *randomColor = [CIColor colorWithRed:RAND_IN_RANGE(0.0, 1.0)
										   green:RAND_IN_RANGE(0.0, 1.0)
											blue:RAND_IN_RANGE(0.0, 1.0)
                                           alpha:RAND_IN_RANGE(0.0, 1.0)];
	return randomColor;
}

@end
