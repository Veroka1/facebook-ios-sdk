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

 #import "FBSDKBridgeAPIResponse.h"

 #import <FBSDKCoreKit_Basics/FBSDKCoreKit_Basics.h>

 #import "FBSDKBridgeAPIRequest+Private.h"
 #import "FBSDKConstants.h"
 #import "FBSDKInternalUtility+Internal.h"
 #import "FBSDKOperatingSystemVersionComparing.h"
 #import "NSProcessInfo+Protocols.h"

@interface FBSDKBridgeAPIResponse ()
- (instancetype)initWithRequest:(id<FBSDKBridgeAPIRequest>)request
             responseParameters:(NSDictionary<NSString *, id> *)responseParameters
                      cancelled:(BOOL)cancelled
                          error:(NSError *)error
  NS_DESIGNATED_INITIALIZER;
@end

@implementation FBSDKBridgeAPIResponse

 #pragma mark - Class Methods

+ (instancetype)bridgeAPIResponseWithRequest:(id<FBSDKBridgeAPIRequest>)request error:(NSError *)error
{
  return [[self alloc] initWithRequest:request
                    responseParameters:nil
                             cancelled:NO
                                 error:error];
}

+ (instancetype)bridgeAPIResponseWithRequest:(NSObject<FBSDKBridgeAPIRequest> *)request
                                 responseURL:(NSURL *)responseURL
                           sourceApplication:(NSString *)sourceApplication
                                       error:(NSError *__autoreleasing *)errorRef
{
  return [self bridgeAPIResponseWithRequest:request
                                responseURL:responseURL
                          sourceApplication:sourceApplication
                          osVersionComparer:NSProcessInfo.processInfo
                                      error:errorRef];
}

+ (instancetype)bridgeAPIResponseWithRequest:(NSObject<FBSDKBridgeAPIRequest> *)request
                                 responseURL:(NSURL *)responseURL
                           sourceApplication:(NSString *)sourceApplication
                           osVersionComparer:(id<FBSDKOperatingSystemVersionComparing>)comparer
                                       error:(NSError *__autoreleasing *)errorRef
{
  FBSDKBridgeAPIProtocolType protocolType = request.protocolType;
  NSOperatingSystemVersion iOS13Version = { .majorVersion = 13, .minorVersion = 0, .patchVersion = 0 };
  if ([comparer isOperatingSystemAtLeastVersion:iOS13Version]) {
    // SourceApplication is not available in iOS 13.
    // https://forums.developer.apple.com/thread/119118
  } else {
    switch (protocolType) {
      case FBSDKBridgeAPIProtocolTypeNative: {
        if (![FBSDKInternalUtility.sharedUtility isFacebookBundleIdentifier:sourceApplication]) {
          if (errorRef != NULL) {
            *errorRef = [[NSError alloc] initWithDomain:FBSDKErrorDomain
                                                   code:FBSDKErrorBridgeAPIResponse
                                               userInfo:nil];
          }
          return nil;
        }
        break;
      }
      case FBSDKBridgeAPIProtocolTypeWeb: {
        if (![FBSDKInternalUtility.sharedUtility isSafariBundleIdentifier:sourceApplication]) {
          if (errorRef != NULL) {
            *errorRef = [[NSError alloc] initWithDomain:FBSDKErrorDomain
                                                   code:FBSDKErrorBridgeAPIResponse
                                               userInfo:nil];
          }
          return nil;
        }
        break;
      }
    }
  }
  NSDictionary<NSString *, NSString *> *const queryParameters = [FBSDKBasicUtility dictionaryWithQueryString:responseURL.query];
  id<FBSDKBridgeAPIProtocol> protocol = request.protocol;
  BOOL cancelled;
  NSError *error;
  NSDictionary<NSString *, id> *responseParameters = [protocol responseParametersForActionID:request.actionID
                                                                             queryParameters:queryParameters
                                                                                   cancelled:&cancelled
                                                                                       error:&error];
  if (errorRef != NULL) {
    *errorRef = error;
  }
  if (!responseParameters) {
    if (errorRef != NULL) {
      *errorRef = [[NSError alloc] initWithDomain:FBSDKErrorDomain code:FBSDKErrorBridgeAPIResponse userInfo:nil];
    }
    return nil;
  }
  return [[self alloc] initWithRequest:request
                    responseParameters:responseParameters
                             cancelled:cancelled
                                 error:error];
}

+ (instancetype)bridgeAPIResponseCancelledWithRequest:(NSObject<FBSDKBridgeAPIRequest> *)request
{
  return [[self alloc] initWithRequest:request
                    responseParameters:nil
                             cancelled:YES
                                 error:nil];
}

 #pragma mark - Object Lifecycle

- (instancetype)initWithRequest:(NSObject<FBSDKBridgeAPIRequest> *)request
             responseParameters:(NSDictionary<NSString *, id> *)responseParameters
                      cancelled:(BOOL)cancelled
                          error:(NSError *)error
{
  if ((self = [super init])) {
    _request = [request copy];
    _responseParameters = [responseParameters copy];
    _cancelled = cancelled;
    _error = [error copy];
  }
  return self;
}

 #pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
  return self;
}

@end

#endif
