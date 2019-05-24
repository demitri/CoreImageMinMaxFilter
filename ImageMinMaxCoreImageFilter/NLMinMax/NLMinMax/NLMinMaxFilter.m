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

BOOL is_power_of_two(unsigned int x);
unsigned int next_power_of_two (unsigned int n);

#pragma mark -

BOOL is_power_of_two(unsigned int x) {
	//
	// Ref: http://www.exploringbinary.com/ten-ways-to-check-if-an-integer-is-a-power-of-two-in-c/
	//
	// Note that this assumes that x will never be zero - use this if that's a possiblility:
	//
	//	return (x && ((x & (~x + 1)) == x));
	//
	return (x & (~x + 1)) == x;
}

unsigned int next_power_of_two (unsigned int n) {
	//
	// Ref: http://stackoverflow.com/questions/1322510/given-an-integer-how-do-i-find-the-next-largest-power-of-two-using-bit-twiddlin
	//		https://web.archive.org/web/20160703165415/
    //      https://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2Float
	//
	n--;
	n |= n >> 1;   // Divide by 2^k for consecutive doublings of k up to 32,
	n |= n >> 2;   // and then or the results.
	n |= n >> 4;
	n |= n >> 8;
	n |= n >> 16;
	n++;           // The result is a number of 1 bits equal to the number
	               // of bits in the original number, plus 1. That's the
				   // next highest power of 2.
	return n;
}

#pragma mark -

@interface NLMinMaxFilter ()
@property (nonatomic, strong) CIColor *transparentBlackColor;
@property (nonatomic, strong) CIFilter *colorFillFilter;
@end

#pragma mark -

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
		
		self.colorFillFilter = [CIFilter filterWithName:@"CIConstantColorGenerator"];
		self.transparentBlackColor = [CIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.0];  // transparent black
		[self.colorFillFilter setValue:self.transparentBlackColor forKey:@"inputColor"];
		
    }
    return [super init];
}

- (NSDictionary *)customAttributes
{
    return @{};
}

- (CGRect)regionOf:(int)samplerIndex destRect:(CGRect)r userInfo:obj
{
	// This method is required when the destination pixel uses more than one pixel from the source image.
	// It is required when the region of intereast (ROI) and domain of defintion (DoD) do not coincide,
	// which will always be the case with a reduction filter.
	//
	// Ref: https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/ImageUnitTutorial/Overview/Overview.html#//apple_ref/doc/uid/TP40004531-CH6-SW2
	//===
	
	//NSLog(@"sample extent: %@", NSStringFromRect([obj extent]));
	return CGRectMake(0, 0, 242, 242); // this is hard coded for testing
}

// called when setting up for fragment program and also calls fragment program
- (CIImage *)outputImage
{
	
	// Is the image size a square whose side is a power of two? If not:
	//    - create a new square image whose size is the smallest factor of two that will contain the image
	//	  - fill it with black pixels, alpha = 0
	//	  - composite input image onto it
	//    - use that image as the input
	
	unsigned int height = (unsigned int)inputImage.extent.size.height;
	unsigned int width = (unsigned int)inputImage.extent.size.width;

	unsigned int n; // dimension of image we will pass to kernel, square of next largest power of 2
	
	if (height == width && is_power_of_two(width))
	{
		// inputImage can be used unmodified
		n = width;
	}
	else
	{
		unsigned int larger_dimension = MAX(height, width);
		n = is_power_of_two(larger_dimension) ? larger_dimension : next_power_of_two(larger_dimension);

		CIImage *powerOfTwoImage = [CIImage imageWithColor:self.transparentBlackColor];		// infinite image
		powerOfTwoImage = [powerOfTwoImage imageByCroppingToRect:CGRectMake(0, 0, n, n)];	// crop to a power of two square
		inputImage = [inputImage imageByCompositingOverImage:powerOfTwoImage];				// composite inputImage onto square
	}
	
	CISampler *src = [CISampler samplerWithImage:inputImage
										 options:@{kCISamplerFilterMode : kCISamplerFilterNearest,
												   kCISamplerWrapMode   : kCISamplerWrapBlack}]; // might also work with "kCISamplerWrapClamp", may be faster?
	
    return [self apply:_NLMinMaxFilterKernel,
			// samplers
			src,
			// inputs
			// -- none --
			// options
			kCIApplyOptionExtent, @[@(0), @(0), @(n/2.), @(n/2.)], // origin x, origin y, width, height
			kCIApplyOptionUserInfo, src,
			nil];
}

@end
