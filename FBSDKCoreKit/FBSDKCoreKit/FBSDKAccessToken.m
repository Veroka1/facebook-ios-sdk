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

#import "FBSDKAccessToken.h"
#import "FBSDKAccessToken+Internal.h"
#import "FBSDKAccessToken+TokenStringProviding.h"

#import <FBSDKCoreKit_Basics/FBSDKCoreKit_Basics.h>

#import "FBSDKError+Internal.h"
#import "FBSDKGraphRequestPiggybackManager.h"
#import "FBSDKInternalUtility+Internal.h"
#import "FBSDKMath.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

NSNotificationName const FBSDKAccessTokenDidChangeNotification = @"com.facebook.sdk.FBSDKAccessTokenData.FBSDKAccessTokenDidChangeNotification";

#else

NSString *const FBSDKAccessTokenDidChangeNotification = @"com.facebook.sdk.FBSDKAccessTokenData.FBSDKAccessTokenDidChangeNotification";

#endif

NSString *const FBSDKAccessTokenDidChangeUserIDKey = @"FBSDKAccessTokenDidChangeUserIDKey";
NSString *const FBSDKAccessTokenChangeNewKey = @"FBSDKAccessToken";
NSString *const FBSDKAccessTokenChangeOldKey = @"FBSDKAccessTokenOld";
NSString *const FBSDKAccessTokenDidExpireKey = @"FBSDKAccessTokenDidExpireKey";

static FBSDKAccessToken *g_currentAccessToken;
static id<FBSDKTokenCaching> g_tokenCache;
static id<FBSDKGraphRequestConnectionFactory> g_graphRequestConnectionFactory;

#define FBSDK_ACCESSTOKEN_TOKENSTRING_KEY @"tokenString"
#define FBSDK_ACCESSTOKEN_PERMISSIONS_KEY @"permissions"
#define FBSDK_ACCESSTOKEN_DECLINEDPERMISSIONS_KEY @"declinedPermissions"
#define FBSDK_ACCESSTOKEN_EXPIREDPERMISSIONS_KEY @"expiredPermissions"
#define FBSDK_ACCESSTOKEN_APPID_KEY @"appID"
#define FBSDK_ACCESSTOKEN_USERID_KEY @"userID"
#define FBSDK_ACCESSTOKEN_REFRESHDATE_KEY @"refreshDate"
#define FBSDK_ACCESSTOKEN_EXPIRATIONDATE_KEY @"expirationDate"
#define FBSDK_ACCESSTOKEN_DATA_EXPIRATIONDATE_KEY @"dataAccessExpirationDate"
#define FBSDK_ACCESSTOKEN_GRAPH_DOMAIN_KEY @"graphDomain"

@implementation FBSDKAccessToken

- (instancetype)initWithTokenString:(NSString *)tokenString
                        permissions:(NSArray *)permissions
                declinedPermissions:(NSArray *)declinedPermissions
                 expiredPermissions:(NSArray *)expiredPermissions
                              appID:(NSString *)appID
                             userID:(NSString *)userID
                     expirationDate:(NSDate *)expirationDate
                        refreshDate:(NSDate *)refreshDate
           dataAccessExpirationDate:(NSDate *)dataAccessExpirationDate
{
  if ((self = [super init])) {
    _tokenString = [tokenString copy];
    _permissions = [NSSet setWithArray:permissions];
    _declinedPermissions = [NSSet setWithArray:declinedPermissions];
    _expiredPermissions = [NSSet setWithArray:expiredPermissions];
    _appID = [appID copy];
    _userID = [userID copy];
    _expirationDate = [expirationDate copy] ?: NSDate.distantFuture;
    _refreshDate = [refreshDate copy] ?: [NSDate date];
    _dataAccessExpirationDate = [dataAccessExpirationDate copy] ?: NSDate.distantFuture;
  }
  return self;
}

- (BOOL)hasGranted:(NSString *)permission
{
  return [self.permissions containsObject:permission];
}

- (BOOL)isDataAccessExpired
{
  return [self.dataAccessExpirationDate compare:NSDate.date] == NSOrderedAscending;
}

- (BOOL)isExpired
{
  return [self.expirationDate compare:NSDate.date] == NSOrderedAscending;
}

+ (id<FBSDKTokenCaching>)tokenCache
{
  return g_tokenCache;
}

+ (void)setTokenCache:(id<FBSDKTokenCaching>)cache
{
  if (g_tokenCache != cache) {
    g_tokenCache = cache;
  }
}

+ (void)resetTokenCache
{
  [FBSDKAccessToken setTokenCache:nil];
}

+ (FBSDKAccessToken *)currentAccessToken
{
  return g_currentAccessToken;
}

+ (NSString *)tokenString
{
  return FBSDKAccessToken.currentAccessToken.tokenString;
}

+ (void)setCurrentAccessToken:(FBSDKAccessToken *)token
{
  [FBSDKAccessToken setCurrentAccessToken:token shouldDispatchNotif:YES];
}

+ (void)setCurrentAccessToken:(nullable FBSDKAccessToken *)token
          shouldDispatchNotif:(BOOL)shouldDispatchNotif
{
  if (token != g_currentAccessToken) {
    NSMutableDictionary<NSString *, id> *userInfo = [NSMutableDictionary dictionary];
    [FBSDKTypeUtility dictionary:userInfo setObject:token forKey:FBSDKAccessTokenChangeNewKey];
    [FBSDKTypeUtility dictionary:userInfo setObject:g_currentAccessToken forKey:FBSDKAccessTokenChangeOldKey];
    // We set this flag also when the current Access Token was not valid, since there might be legacy code relying on it
    if (![g_currentAccessToken.userID isEqualToString:token.userID] || !self.isCurrentAccessTokenActive) {
      userInfo[FBSDKAccessTokenDidChangeUserIDKey] = @YES;
    }

    g_currentAccessToken = token;

    // Only need to keep current session in web view for the case when token is current
    // When token is abandoned cookies must to be cleaned up immediately
    if (token == nil) {
      [FBSDKInternalUtility.sharedUtility deleteFacebookCookies];
    }

    self.tokenCache.accessToken = token;
    if (shouldDispatchNotif) {
      [NSNotificationCenter.defaultCenter postNotificationName:FBSDKAccessTokenDidChangeNotification
                                                        object:self.class
                                                      userInfo:userInfo];
    }
  }
}

+ (BOOL)isCurrentAccessTokenActive
{
  FBSDKAccessToken *currentAccessToken = [self currentAccessToken];
  return currentAccessToken != nil && !currentAccessToken.isExpired;
}

+ (void)refreshCurrentAccessTokenWithCompletion:(nullable FBSDKGraphRequestCompletion)completion
{
  if ([FBSDKAccessToken currentAccessToken]) {
    id<FBSDKGraphRequestConnecting> connection = [FBSDKAccessToken.graphRequestConnectionFactory createGraphRequestConnection];
    [FBSDKGraphRequestPiggybackManager addRefreshPiggyback:connection permissionHandler:completion];
    [connection start];
  } else if (completion) {
    completion(
      nil,
      nil,
      [FBSDKError
       errorWithCode:FBSDKErrorAccessTokenRequired
       message:@"No current access token to refresh"]
    );
  }
}

+ (id<FBSDKGraphRequestConnectionFactory>)graphRequestConnectionFactory
{
  return g_graphRequestConnectionFactory;
}

+ (void)setGraphRequestConnectionFactory:(nonnull id<FBSDKGraphRequestConnectionFactory>)graphRequestConnectionFactory
{
  if (g_graphRequestConnectionFactory != graphRequestConnectionFactory) {
    g_graphRequestConnectionFactory = graphRequestConnectionFactory;
  }
}

#pragma mark - Equality

- (NSUInteger)hash
{
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSUInteger subhashes[] = {
    self.tokenString.hash,
    self.permissions.hash,
    self.declinedPermissions.hash,
    self.expiredPermissions.hash,
    self.appID.hash,
    self.userID.hash,
    self.refreshDate.hash,
    self.expirationDate.hash,
    self.dataAccessExpirationDate.hash,
  };
  #pragma clange diagnostic pop

  return [FBSDKMath hashWithIntegerArray:subhashes count:sizeof(subhashes) / sizeof(subhashes[0])];
}

- (BOOL)isEqual:(id)object
{
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:FBSDKAccessToken.class]) {
    return NO;
  }
  return [self isEqualToAccessToken:(FBSDKAccessToken *)object];
}

- (BOOL)isEqualToAccessToken:(FBSDKAccessToken *)token
{
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wdeprecated-declarations"
  return (token
    && [FBSDKInternalUtility.sharedUtility object:self.tokenString isEqualToObject:token.tokenString]
    && [FBSDKInternalUtility.sharedUtility object:self.permissions isEqualToObject:token.permissions]
    && [FBSDKInternalUtility.sharedUtility object:self.declinedPermissions isEqualToObject:token.declinedPermissions]
    && [FBSDKInternalUtility.sharedUtility object:self.expiredPermissions isEqualToObject:token.expiredPermissions]
    && [FBSDKInternalUtility.sharedUtility object:self.appID isEqualToObject:token.appID]
    && [FBSDKInternalUtility.sharedUtility object:self.userID isEqualToObject:token.userID]
    && [FBSDKInternalUtility.sharedUtility object:self.refreshDate isEqualToObject:token.refreshDate]
    && [FBSDKInternalUtility.sharedUtility object:self.expirationDate isEqualToObject:token.expirationDate]
    && [FBSDKInternalUtility.sharedUtility object:self.dataAccessExpirationDate isEqualToObject:token.dataAccessExpirationDate]);
  #pragma clange diagnostic pop
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
  // we're immutable.
  return self;
}

#pragma mark NSCoding

+ (BOOL)supportsSecureCoding
{
  return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
  NSString *appID = [decoder decodeObjectOfClass:NSString.class forKey:FBSDK_ACCESSTOKEN_APPID_KEY];
  NSSet *declinedPermissions = [decoder decodeObjectOfClass:NSSet.class forKey:FBSDK_ACCESSTOKEN_DECLINEDPERMISSIONS_KEY];
  NSSet *expiredPermissions = [decoder decodeObjectOfClass:NSSet.class forKey:FBSDK_ACCESSTOKEN_EXPIREDPERMISSIONS_KEY];
  NSSet *permissions = [decoder decodeObjectOfClass:NSSet.class forKey:FBSDK_ACCESSTOKEN_PERMISSIONS_KEY];
  NSString *tokenString = [decoder decodeObjectOfClass:NSString.class forKey:FBSDK_ACCESSTOKEN_TOKENSTRING_KEY];
  NSString *userID = [decoder decodeObjectOfClass:NSString.class forKey:FBSDK_ACCESSTOKEN_USERID_KEY];
  NSDate *refreshDate = [decoder decodeObjectOfClass:NSDate.class forKey:FBSDK_ACCESSTOKEN_REFRESHDATE_KEY];
  NSDate *expirationDate = [decoder decodeObjectOfClass:NSDate.class forKey:FBSDK_ACCESSTOKEN_EXPIRATIONDATE_KEY];
  NSDate *dataAccessExpirationDate = [decoder decodeObjectOfClass:NSDate.class forKey:FBSDK_ACCESSTOKEN_DATA_EXPIRATIONDATE_KEY];

  return
  [self
   initWithTokenString:tokenString
   permissions:permissions.allObjects
   declinedPermissions:declinedPermissions.allObjects
   expiredPermissions:expiredPermissions.allObjects
   appID:appID
   userID:userID
   expirationDate:expirationDate
   refreshDate:refreshDate
   dataAccessExpirationDate:dataAccessExpirationDate];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
  [encoder encodeObject:self.appID forKey:FBSDK_ACCESSTOKEN_APPID_KEY];
  [encoder encodeObject:self.declinedPermissions forKey:FBSDK_ACCESSTOKEN_DECLINEDPERMISSIONS_KEY];
  [encoder encodeObject:self.expiredPermissions forKey:FBSDK_ACCESSTOKEN_EXPIREDPERMISSIONS_KEY];
  [encoder encodeObject:self.permissions forKey:FBSDK_ACCESSTOKEN_PERMISSIONS_KEY];
  [encoder encodeObject:self.tokenString forKey:FBSDK_ACCESSTOKEN_TOKENSTRING_KEY];
  [encoder encodeObject:self.userID forKey:FBSDK_ACCESSTOKEN_USERID_KEY];
  [encoder encodeObject:self.expirationDate forKey:FBSDK_ACCESSTOKEN_EXPIRATIONDATE_KEY];
  [encoder encodeObject:self.refreshDate forKey:FBSDK_ACCESSTOKEN_REFRESHDATE_KEY];
  [encoder encodeObject:self.dataAccessExpirationDate forKey:FBSDK_ACCESSTOKEN_DATA_EXPIRATIONDATE_KEY];
}

#pragma mark - Testability

#if DEBUG
 #if FBTEST

+ (void)resetCurrentAccessTokenCache
{
  g_currentAccessToken = nil;
}

 #endif
#endif

@end
