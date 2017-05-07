//
//  NLMinMaxFilter.h
//  NLMinMax
//
//  Created by Demitri Muna on 3/18/17.
//  Copyright © 2017 Demitri Muna. All rights reserved.
//

/*
 This reduction filter calculates the minimum or maximum float value from a CIImage.
 */

#import <QuartzCore/QuartzCore.h>

typedef enum {
	NL_IMAGE_MIN = 0,
	NL_IMAGE_MAX
} NLFilterType;

@interface NLMinMaxFilter : CIFilter {
    CIImage      *inputImage;
}

@end
