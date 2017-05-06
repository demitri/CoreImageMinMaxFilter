//
//  AppDelegate.m
//  ImageMinMaxCoreImageFilter
//
//  Created by Demitri Muna on 3/18/17.
//  Copyright © 2017 Demitri Muna. All rights reserved.
//

#import "AppDelegate.h"
@import CoreImage;

// This takes a float array and normalizes it to [0,1]
//
void normalizeFloatArray01MinMax(float *a, unsigned long nelements, float min, float max)
{
	float delta = max - min;
	for (int i=0; i < nelements; i++) {
		a[i] = (a[i] - min) / delta;
	}
}

#pragma mark -

@interface AppDelegate ()
@property (weak) IBOutlet NSWindow *window;
- (void)_loadCustomCIFilters;
- (CIImage*)_readImageFromFile;
- (CIImage*)_ciImageFromData:(float*)data length:(int)dataLength width:(int)width height:(int)height;
@end

#pragma mark -

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	
	[self _loadCustomCIFilters];
	
	// get source CIImage (choose one), self.imageExtent is set in each method
	self.sourceImage = [self _readImageFromFile];
//	self.sourceImage = [self _generateRandomImage];

	// display source image
	NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:self.sourceImage];
	NSImage *nsImage = [[NSImage alloc] initWithSize:rep.size];
	[nsImage addRepresentation:rep];
	self.sourceImageView.image = nsImage;

	// register CIFilter
	CIFilter *minMaxFilter = [CIFilter filterWithName:@"NLMinMaxFilter"];
	NSAssert(minMaxFilter, @"minMaxFilter not created");
	
	// set up filter
	[minMaxFilter setValue:self.sourceImage forKey:kCIInputImageKey];
	
	// apply filter
	CIImage *outputImage = [minMaxFilter valueForKey:kCIOutputImageKey];
	NSAssert(outputImage, @"minPixelFilter image not created.");
	
	NSLog(@"output image extent: %@", NSStringFromRect(outputImage.extent));
	
	// display output image
	rep = [NSCIImageRep imageRepWithCIImage:outputImage];
	nsImage = [[NSImage alloc] initWithSize:rep.size];
	[nsImage addRepresentation:rep];
	self.destImageView.image = nsImage;
	
	// read individual pixel values to see if the filter worked
	CIContext *context = [[CIContext alloc] init];
	CGImageRef cgImageRef = [context createCGImage:outputImage
											 fromRect:outputImage.extent];
	CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(cgImageRef));
	UInt8 * buf = (UInt8 *) CFDataGetBytePtr(rawData);
	CFIndex length = CFDataGetLength(rawData);

	NSLog(@"data length: %ld", length);
	
	// print out all pixel values
	for (CFIndex i=0; i < length; i+=4) {
		int r = buf[0];
		int g = buf[1];
		int b = buf[2];
		int a = buf[2];
		NSLog(@"Pixels: rbg[%ld] = [%d, %d, %d, %d]", i/4, r, g, b, a);
	}
	
	CFRelease(rawData);
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}

- (CIImage*)_generateRandomImage
{
	// Create a CIImage from float data n x n square, randomly generated.
	// Values are float in [a,b].
	
	int n = 256;

	float a = 0.0;
	float b = 1000.0;
	srand(123456);
	
	float *data = calloc(n, sizeof(float));
	float min = MAXFLOAT;
	for (int i=0; i < n; i++) {
		data[i] = a + rand() / (RAND_MAX / (b - a + 1) + 1);
		//data[i] = i/n;
		if (data[i] < min)
			min = data[i];
		//NSLog(@"values: %f", data[i]);
	}

	self.imageExtent = [CIVector vectorWithX:0 Y:0 Z:n W:n];

	NSLog(@"min value: %f", min);
	
	return [self _ciImageFromData:data
						   length:n*n*sizeof(float)
							width:n
						   height:n];
}

- (CIImage*)_readImageFromFile
{
	// Create CIImage from a binary file of float data.
	// This is not an RGB, only a list of floats (i.e. monoscale intensity).
	
	//CIImage *_image;
	
	// dimensions
	const size_t width = 242;
	const size_t height = 242;
	//const size_t bytesPerRow = width * sizeof(float);
	NSUInteger n = width * height;
	NSUInteger dataLength = sizeof(float) * n;
	
	self.imageExtent = [CIVector vectorWithX:0 Y:0 Z:width W:height];
	
	// read the data
	float* data = malloc(dataLength);
	NSString *dataFilePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"data.bin"];
	FILE *rawDataFile = fopen(dataFilePath.UTF8String, "r");
	fread(data, sizeof(float), width*height, rawDataFile);
	fclose(rawDataFile);
	
	// print the min, max values calculated by hand
	float min = data[0];
	float max = data[0];
	unsigned int notFiniteCount = 0;
	for (unsigned int i=1; i < n; i++) {
		if (data[i] < min)
			min = data[i];
		if (data[i] > max)
			max = data[i];
		if (!isfinite(data[i])) {
			notFiniteCount++;
		}
	}
	NSLog(@"Minimum value in original array: %f", min);
	NSLog(@"Maximum value in original array: %f", max);
	NSLog(@"No. of non-finite values: %d", notFiniteCount);
	
	normalizeFloatArray01MinMax(data, n, min, max);

	return [self _ciImageFromData:data
						   length:width*height*sizeof(float)
							width:width
						   height:height];
}

- (CIImage*)_ciImageFromData:(float*)data length:(int)dataLength width:(int)width height:(int)height
{
	const size_t bytesPerRow = width * sizeof(float);
	
	// create the image
	NSData *nsData = [NSData dataWithBytesNoCopy:data length:dataLength freeWhenDone:YES];
	CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((CFDataRef)nsData);
	CGBitmapInfo bitmapInfo = kCGImageAlphaNone | kCGBitmapByteOrder32Host | kCGBitmapFloatComponents;
	CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
	
	CGImageRef cgImage = CGImageCreate(width,			// size_t width
									   height,			// size_t height
									   32,				// size_t bitsPerComponent (float=32)
									   32,				// size_t bitsPerPixel == bitsPerComponent for float
									   bytesPerRow,		// size_t bytesPerRow
									   colorSpace,		// CGColorSpaceRef
									   bitmapInfo,		// CGBitmapInfo
									   dataProvider,	// CGDataProviderRef
									   NULL,			// const CGFloat decode[] - NULL = do not want to allow
									   //   remapping of the image’s color values
									   NO,				// shouldInterpolate
									   kCGRenderingIntentDefault); // CGColorRenderingIntent
	
	NSAssert(cgImage != nil, @"could not create image");
	
	CIImage *image = [CIImage imageWithCGImage:cgImage
									   options:@{kCIImageColorSpace: [NSNull null]}];
	
	// clean up
	CGDataProviderRelease(dataProvider);
	CGColorSpaceRelease(colorSpace);
	CGImageRelease(cgImage);

	return image;
}

- (void)_loadCustomCIFilters
{
	NSURL *pluginURL;
	// these are the plug-in names, not the filter names
	// don't forget to add to target dependencies and plug-in copy phase
	NSArray *pluginsToLoad = @[@"NLMinMax"];
	NSString *pluginPath = [[NSBundle mainBundle] builtInPlugInsPath];
	NSString *pluginFilename;
	
	for (NSString *pluginName in pluginsToLoad) {
		pluginFilename = [pluginName stringByAppendingString:@".plugin"];
		pluginURL = [NSURL fileURLWithPathComponents:@[pluginPath, pluginFilename]];
		
		// check that the plugins are there as expected
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if (![fileManager fileExistsAtPath:pluginURL.path])
			NSAssert(false, @"expected plugin not found: %@", pluginURL);
		
		[CIPlugIn loadPlugIn:pluginURL allowExecutableCode:YES];
	}
}

@end
