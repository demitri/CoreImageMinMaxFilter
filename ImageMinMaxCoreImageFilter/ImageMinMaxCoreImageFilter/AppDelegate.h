//
//  AppDelegate.h
//  ImageMinMaxCoreImageFilter
//
//  Created by Demitri Muna on 3/18/17.
//  Copyright © 2017 Demitri Muna. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) CIImage *sourceImage;
@property (nonatomic, strong) CIVector *imageExtent;

@property (nonatomic, weak) IBOutlet NSImageView *sourceImageView;
@property (nonatomic, weak) IBOutlet NSImageView *destImageView;

@end

