// Copyright (c) 2014-present, Facebook, Inc. All rights reserved.
//
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Facebook.
//
// As with any software that integrates with the Facebook platform, your use of
// this software is subject to the Facebook Developer Principles and Policies
// [http://developers.facebook.com/policy/]. This copyright notice shall be
// included in all copies or substantial portions of the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "TargetConditionals.h"

#if !TARGET_OS_TV

#import <UIKit/UIKit.h>

#import "FBSDKLikeObjectType.h"

NS_ASSUME_NONNULL_BEGIN

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

FOUNDATION_EXPORT NSNotificationName const FBSDKLikeActionControllerDidDisableNotification;
FOUNDATION_EXPORT NSNotificationName const FBSDKLikeActionControllerDidResetNotification;
FOUNDATION_EXPORT NSNotificationName const FBSDKLikeActionControllerDidUpdateNotification;

#else

FOUNDATION_EXPORT NSString *const FBSDKLikeActionControllerDidDisableNotification;
FOUNDATION_EXPORT NSString *const FBSDKLikeActionControllerDidResetNotification;
FOUNDATION_EXPORT NSString *const FBSDKLikeActionControllerDidUpdateNotification;

#endif

FOUNDATION_EXPORT NSString *const FBSDKLikeActionControllerAnimatedKey;

NS_SWIFT_NAME(LikeActionController)
@interface FBSDKLikeActionController : NSObject <NSDiscardableContent, NSSecureCoding>

+ (BOOL)isDisabled;

// this method will call beginContentAccess before returning the instance
+ (instancetype)likeActionControllerForObjectID:(NSString *)objectID objectType:(FBSDKLikeObjectType)objectType;

@property (nonatomic, copy, readonly) NSDate *lastUpdateTime;
@property (nonatomic, copy, readonly) NSString *likeCountString;
@property (nonatomic, copy, readonly) NSString *objectID;
@property (nonatomic, assign, readonly) FBSDKLikeObjectType objectType;
@property (nonatomic, assign, readonly) BOOL objectIsLiked;
@property (nonatomic, copy, readonly) NSString *socialSentence;

- (void)refresh;

@end

#endif

NS_ASSUME_NONNULL_END
