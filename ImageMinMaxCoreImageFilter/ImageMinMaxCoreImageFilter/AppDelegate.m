//
//  AppDelegate.m
//  ImageMinMaxCoreImageFilter
//
//  Created by Demitri Muna on 3/18/17.
//  Copyright © 2017 Demitri Muna. All rights reserved.
//

#import "AppDelegate.h"
#import "math.h"
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
	
	// -----------------------------------------------
	// Load image from file, display unaltered in view
	// -----------------------------------------------
	
	// get source CIImage (choose one), self.imageExtent is set in each method
	self.sourceImage = [self _readImageFromFile];
	//self.sourceImage = [self _generateRandomImage];

	// display source image
	NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:self.sourceImage];
	NSImage *nsImage = [[NSImage alloc] initWithSize:rep.size];
	[nsImage addRepresentation:rep];
	self.sourceImageView.image = nsImage;

	// --------------------------------
	// Repeat, but apply NLMinMaxFilter
	// --------------------------------
	// register min/max CIFilter
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
	
	// --------------------------------------------
	// Read the pixel values from the output image.
	// --------------------------------------------
	{
		/*
		// Option 1, based on
		// https://stackoverflow.com/a/3763313/2712652
		//
		
		// The bitmap context created here is invalid.
		
		CGImageRef outputImageRef = outputImage.CGImage;
		float pixel[3] = {0,0,0}; // one pixel, three floats (RGB), no alpha
		uint32_t bitmapInfo = kCGImagePixelFormatPacked | kCGImageAlphaNone;// | kCGBitmapByteOrder32Host | kCGBitmapFloatComponents; <-- lead to invalid context
		CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();

		CGContextRef outputImageContext = CGBitmapContextCreate(pixel,		// data
																1,			// width
																1,			// height
																8,			// bits per component
																1,			// bytes per row
																colorspace,	// colorspace ref
																bitmapInfo); // bitmapInfo
		CGContextDrawImage(outputImageContext, CGRectMake(0, 0, 1, 1), outputImageRef);
		CGContextRelease(outputImageContext);
		CGColorSpaceRelease(colorspace);
		NSLog(@"option 1 pixel value = %f\n", pixel[0]);
		 */
	}
	
	 // ----------------------------
	
	// Read individual pixel values to see if the filter worked.
	// Make sure color space operations are not being performed anywhere.
	{
		// Option 2
		//
		CIContext *context = [CIContext contextWithOptions:@{kCIContextOutputColorSpace:[NSNull null],
															 kCIContextWorkingColorSpace:[NSNull null]}];
		CGImageRef cgImageRef = [context createCGImage:outputImage
											  fromRect:outputImage.extent];
		CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(cgImageRef));
		UInt8 * buf = (UInt8 *) CFDataGetBytePtr(rawData);
		float *floatPointer = (float*) CFDataGetBytePtr(rawData); // <- does not contain the values I'm expecting

		CFIndex length = CFDataGetLength(rawData);
		NSLog(@"data length: %ld (sqrt=%.f)", length, sqrtf((float)length));

		length = 4; // except length should be 3 (RGB) or 4 (RGBA) -> one pixel; rest of array is zeros
		
		int minValue = INT_MAX;
		int maxValue = -INT_MAX;
		
		// print out all pixel values
		for (CFIndex i=0; i < length; i+=4) {
			int r = buf[i+0];
			int g = buf[i+1];
			int b = buf[i+2];
			int a = buf[i+3];
			NSLog(@"Pixels: rbg[%ld] = [%.5f, %.5f, %.5f, %.5f]", i/4, r/255., g/255., b/255., a/255.);
			
			minValue = MIN(minValue, r);
			maxValue = MAX(maxValue, r);
		}
		
		NSLog(@"Min pixel from filter: %.5f", minValue/255.);
		NSLog(@"Max pixel from filter: %.5f", maxValue/255.);
		
		CFRelease(rawData);
	}
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}

- (CIImage*)_generateRandomImage
{
	// Create a CIImage from float data 242 x 242 square, randomly generated.
	// Values are float in [a,b].
	
	int width = 242;
	int height = 242;
	int n = width * height;

	float a = 0.25;
	float b = 0.9;
	//srand(123456);

	float *data = calloc(n, sizeof(float));
	float min = MAXFLOAT;
	for (int i=0; i < n; i++) {
		float scale = rand() / (float)RAND_MAX; // random value in [0,1]
		data[i] = a + scale * (b - a);
		if (data[i] < min)
			min = data[i];
		//NSLog(@"values: %f", data[i]);
	}

	self.imageExtent = [CIVector vectorWithX:0 Y:0 Z:width W:height];

	NSLog(@"min value from random data: %f", min);

	normalizeFloatArray01MinMax(data, n, a, b);
	
	return [self _ciImageFromData:data
						   length:n*sizeof(float)
							width:width
						   height:height];
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
									   32,				// size_t bitsPerComponent (float: 4 bytes = 32 bits)
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
