//
//  NLMinMaxFilter.m
//  NLMinMax
//
//  Created by Demitri Muna on 3/18/17.
//  Copyright © 2017 Demitri Muna. All rights reserved.
//

#import "NLMinMaxFilter.h"
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

@implementation NLMinMaxFilter

static CIKernel *_NLMinMaxFilterKernel = nil;

- (instancetype)init
{
    if(!_NLMinMaxFilterKernel) {
        NSBundle    *bundle = [NSBundle bundleForClass:NSClassFromString(@"NLMinMaxFilter")];
        NSStringEncoding encoding = NSUTF8StringEncoding;
        NSError     *error = nil;
        NSString    *code = [NSString stringWithContentsOfFile:[bundle pathForResource:@"NLMinMaxFilterKernel" ofType:@"cikernel"]
													  encoding:encoding
														 error:&error];
        NSArray     *kernels = [CIKernel kernelsWithString:code];

        _NLMinMaxFilterKernel = kernels[0];
    }
    return [super init];
}

/*
- (CGRect)regionOf:(int)sampler  destRect:(CGRect)rect  userInfo:(NSNumber *)radius
{
    return CGRectInset(rect, -[radius floatValue], 0);
}
*/

- (NSDictionary *)customAttributes
{
    return @{};
}

// called when setting up for fragment program and also calls fragment program
- (CIImage *)outputImage
{
	CISampler *src = [CISampler samplerWithImage:inputImage
										 options:@{kCISamplerFilterMode : kCISamplerFilterNearest,
												   kCISamplerWrapMode   : kCISamplerWrapBlack}];
	
    return [self apply:_NLMinMaxFilterKernel,
			// samplers
			src,
			// inputs
			// -- none --
			// options
			kCIApplyOptionExtent, @[@0, @0, @128, @128],
			nil];
}

@end
