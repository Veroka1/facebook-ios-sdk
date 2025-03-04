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

 #import "FBSDKCreateContextContent.h"

 #import <FBSDKCoreKit/FBSDKCoreKit.h>

 #define FBSDK_APP_REQUEST_CONTENT_PLAYER_ID_KEY @"playerID"
@interface FBSDKCreateContextContent () <NSCopying, NSObject>
@end

@implementation FBSDKCreateContextContent

- (instancetype)initDialogContentWithPlayerID:(NSString *)playerID;
{
  if ((self = [super init])) {
    self.playerID = playerID;
  }
  return self;
}

 #pragma mark - FBSDKSharingValidation

- (BOOL)validateWithError:(NSError *__autoreleasing *)errorRef
{
  BOOL hasPlayerID = self.playerID.length > 0;
  if (!hasPlayerID) {
    if (errorRef != NULL) {
      NSString *message = @"The playerID is required.";
      *errorRef = [FBSDKError requiredArgumentErrorWithDomain:FBSDKErrorDomain
                                                         name:@"playerID"
                                                      message:message];
    }
    return NO;
  }
  return YES;
}

 #pragma mark - Equality

- (NSUInteger)hash
{
  NSUInteger subhashes[] = {
    self.playerID.hash,
  };
  return [self hashWithIntegerArray:subhashes count:1];
}

// TODO - delete when we convert to Swift and can use Hashable
- (NSUInteger)hashWithInteger:(NSUInteger)value1 andInteger:(NSUInteger)value2
{
  return [self hashWithLong:(((unsigned long long)value1) << 32 | value2)];
}

// TODO - delete when we convert to Swift and can use Hashable
- (NSUInteger)hashWithIntegerArray:(NSUInteger *)values count:(NSUInteger)count
{
  if (count == 0) {
    return 0;
  }
  NSUInteger hash = values[0];
  for (NSUInteger i = 1; i < count; ++i) {
    hash = [self hashWithInteger:hash andInteger:values[i]];
  }
  return hash;
}

// TODO - delete when we convert to Swift and can use Hashable
- (NSUInteger)hashWithLong:(unsigned long long)value
{
  value = (~value) + (value << 18); // key = (key << 18) - key - 1;
  value ^= (value >> 31);
  value *= 21; // key = (key + (key << 2)) + (key << 4);
  value ^= (value >> 11);
  value += (value << 6);
  value ^= (value >> 22);
  return (NSUInteger)value;
}

- (BOOL)isEqual:(id)object
{
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:FBSDKCreateContextContent.class]) {
    return NO;
  }
  return [self isEqualToContextCreateAsyncContent:(FBSDKCreateContextContent *)object];
}

- (BOOL)isEqualToContextCreateAsyncContent:(FBSDKCreateContextContent *)content
{
  return (content
    && [FBSDKInternalUtility.sharedUtility object:self.playerID isEqualToObject:content.playerID]);
}

 #pragma mark - NSCoding

+ (BOOL)supportsSecureCoding
{
  return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
  if ((self = [self init])) {
    self.playerID = [decoder decodeObjectOfClass:NSString.class forKey:FBSDK_APP_REQUEST_CONTENT_PLAYER_ID_KEY];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
  [encoder encodeObject:self.playerID forKey:FBSDK_APP_REQUEST_CONTENT_PLAYER_ID_KEY];
}

 #pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
  FBSDKCreateContextContent *contentCopy = [FBSDKCreateContextContent new];
  contentCopy.playerID = [self.playerID copy];
  return contentCopy;
}

@end

#endif
