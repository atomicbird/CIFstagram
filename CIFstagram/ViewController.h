//
//  ViewController.h
//  CIFstagram
//
//  Created by Tom Harrington on 2/12/13.
//  Copyright (c) 2013 Tom Harrington. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutletCollection(UIBarButtonItem) NSArray *tabBarButtons;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *pictureButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *enhanceButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *faceZoomButton;

- (IBAction)enhance:(id)sender;
- (IBAction)faceZoom:(id)sender;
- (IBAction)save:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)getPicture:(id)sender;
@end
