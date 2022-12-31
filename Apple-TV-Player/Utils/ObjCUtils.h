//
//  ObjCUtils.h
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 31.12.2022.
//

#ifndef ObjCUtils_h
#define ObjCUtils_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCUtilsMemStat : NSObject

@property unsigned long usedMem;
@property unsigned long freeMem;
@property unsigned long totalMem;

@end

@interface ObjCUtils : NSObject

+ (nullable ObjCUtilsMemStat *)memStats;

@end

NS_ASSUME_NONNULL_END

#endif /* ObjCUtils_h */
