//
//  NLMinMaxPlugInLoader.h
//  NLMinMax
//
//  Created by Demitri Muna on 3/18/17.
//  Copyright © 2017 Demitri Muna. All rights reserved.
//

#import <QuartzCore/CoreImage.h>

@interface NLMinMaxPlugInLoader : NSObject <CIPlugInRegistration>

- (BOOL)load:(void *)host;

@end
