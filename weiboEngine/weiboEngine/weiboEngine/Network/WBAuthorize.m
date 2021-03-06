//
//  WBAuthorize.m
//  weiboEngine
//
//  Created by zhe wang on 11-9-30.
//  Copyright 2011年 nasa.wang. All rights reserved.
//

#import "WBAuthorize.h"
#import "WBUtil.h"
#import <UIKit/UIKit.h>
#import "WeiBo.h"

static NSString* oauthGetRequestTokenURL	= @"http://api.t.sina.com.cn/oauth/request_token";
static NSString* oauthUserAuthorizeURL		= @"http://api.t.sina.com.cn/oauth/authorize";
static NSString* oauthGetAccessTokenURL		= @"http://api.t.sina.com.cn/oauth/access_token";


@interface WBAuthorize (Private)
+ (NSString*)stringFromDictionaryForOAuthRequestHeadField:(NSDictionary *)info;
+ (NSString*)stringFromDictionary:(NSDictionary*)info;
+ (NSString*)getSignatureBaseStringWithHttpMethod:(NSString*)httpMethod withURL:(NSString*)URL withHeadInfo:(NSDictionary*)headInfo;
+ (NSDictionary*)infoFromOAuthRequestReturnString:(NSString*)string;

- (void)gettingRequestTokenUsingOAuth;
- (void)openUserAuthorizePage;
- (void)getAccessTokenWithVerifier:(NSString*)verifier;
@end


@implementation WBAuthorize
@synthesize delegate=_delegate,waitingUserAuthorize=_waitingUserAuthorize;
+ (NSString*)stringFromDictionaryForOAuthRequestHeadField:(NSDictionary *)info
{
	NSMutableArray* pairs = [NSMutableArray array];
	for (NSString* key in [info keyEnumerator]) 
	{
		if( ([[info objectForKey:key] isKindOfClass:[NSString class]]) == FALSE)
			continue;
		
		[pairs addObject:[NSString stringWithFormat:@"%@=\"%@\"", key, [[info objectForKey:key]URLEncodedString]]];
	}
	
	return [NSString stringWithFormat:@"OAuth %@",[pairs componentsJoinedByString:@","]];
}

+ (NSString*)stringFromDictionary:(NSDictionary*)info
{
	NSMutableArray* pairs = [NSMutableArray array];
	
	NSArray* keys = [info allKeys];
	keys = [keys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	for (NSString* key in keys) 
	{
		if( ([[info objectForKey:key] isKindOfClass:[NSString class]]) == FALSE)
			continue;
		
		[pairs addObject:[NSString stringWithFormat:@"%@=%@", key, [[info objectForKey:key]URLEncodedString]]];
	}
	
	return [pairs componentsJoinedByString:@"&"];
}

+ (NSString*)getSignatureBaseStringWithHttpMethod:(NSString*)httpMethod withURL:(NSString*)URL withHeadInfo:(NSDictionary*)headInfo
{
	NSMutableString* baseString = [NSMutableString stringWithCapacity:200];
	[baseString appendString:httpMethod];
	[baseString appendString:@"&"];
	[baseString appendString:[URL URLEncodedString]];
	[baseString appendString:@"&"];
	[baseString appendString:[[WBAuthorize stringFromDictionary:headInfo] URLEncodedString]];
	
	return [NSString stringWithString:baseString];
}

+ (NSDictionary*)infoFromOAuthRequestReturnString:(NSString*)string
{
	NSArray* stringArray = [string componentsSeparatedByString:@"&"];
	
	NSMutableDictionary* info = [NSMutableDictionary dictionaryWithCapacity:10];
	for (NSString* divString in stringArray) 
	{
		NSArray* array = [divString componentsSeparatedByString:@"="];
		if( [array count]!=2 )continue;
		[info setObject:[array objectAtIndex:1] forKey:[array objectAtIndex:0]];
	}
	return [NSDictionary dictionaryWithDictionary:info];
}


- (id)initWithAppKey:(NSString*)app_key 
	   withAppSecret:(NSString*)app_secret 
   withWeiBoInstance:(WeiBo*)weibo
{
	if (self = [super init]) {
		_appKey		= [[NSString alloc]initWithString:app_key];
		_appSecret	= [[NSString alloc]initWithString:app_secret];
		_weibo		= weibo;
	}
	return self;
}

- (void)dealloc
{
	_weibo = nil;
	[_appKey release];_appKey=nil;
	[_appSecret release];_appSecret=nil;
	
	if( _requestToken )
	{
		[_requestToken release];
		_requestToken = nil;
	}
	if( _requestSecret )
	{
		[_requestSecret release];
		_requestSecret = nil;
	}
    
    if (_defaultAccount) {
		[_defaultAccount release];
		_defaultAccount = nil;
    }
    
    if (_defaultPassword) {
		[_defaultPassword release];
		_defaultPassword = nil;
    }
    
    if (_account) {
		[_account release];
		_account = nil;
    }
    
    if (_password) {
		[_password release];
		_password = nil;
    }    
    
	[super dealloc];
}

- (void)startAuthorize
{
	[self gettingRequestTokenUsingOAuth];
}

- (void)startAuthorizeByAccount:(NSString *)account Password:(NSString *)password {
    _account  = [account retain];
    _password = [password retain];
	[self gettingRequestTokenUsingOAuth];    
}
- (void)startAuthorizeDefaultByAccount:(NSString *)account Password:(NSString *)password {
    _defaultAccount  = [account retain];
    _defaultPassword = [password retain];
	[self gettingRequestTokenUsingOAuth];
}

- (void)gettingRequestTokenUsingOAuth
{
	NSMutableDictionary* getRequestTokenHeadInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
													_appKey,@"oauth_consumer_key",
													@"HMAC-SHA1",@"oauth_signature_method",
													[NSString stringWithFormat:@"%.0f",[[NSDate date]timeIntervalSince1970]],@"oauth_timestamp",
													[NSString GUIDString],@"oauth_nonce",
													@"1.0",@"oauth_version",nil];
	
	NSString* baseString = [WBAuthorize getSignatureBaseStringWithHttpMethod:@"POST" withURL:oauthGetRequestTokenURL withHeadInfo:getRequestTokenHeadInfo];
	NSString* keyString = [[_appSecret URLEncodedString] stringByAppendingString:@"&"];
	NSString* signatureString = [[baseString HMACSHA1EncodedDataWithKey:keyString]base64EncodedString];
	
	[getRequestTokenHeadInfo setObject:signatureString forKey:@"oauth_signature"];
	
	if( _request )
	{
		[_request release];
		_request = nil;
	}
	_request = [WBRequest getRequestWithParams:nil
									httpMethod:@"POST" 
								  postDataType:WBRequestPostDataType_Normal 
									  delegate:self 
									requestURL:oauthGetRequestTokenURL 
							  headerFieldsInfo:[NSDictionary dictionaryWithObject:[WBAuthorize stringFromDictionaryForOAuthRequestHeadField:getRequestTokenHeadInfo] forKey:@"Authorization"]];
	
	[_request connect];
	
	[_request retain];
}

- (void)gettingRequestTokenSuccessWithData:(NSData*)data
{
	NSString* string = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
	if( [string rangeOfString:@"error"].location == NSNotFound )
	{
		NSDictionary* info = [WBAuthorize infoFromOAuthRequestReturnString:string];
		if( [info count] >= 2 )
		{
			if( _requestToken )
			{
				[_requestToken release];
				_requestToken = nil;
			}
			_requestToken = [[info objectForKey:@"oauth_token"]retain];
            
			
			if( _requestSecret )
			{
				[_requestSecret release];
				_requestSecret = nil;
			}
			_requestSecret = [[info objectForKey:@"oauth_token_secret"]retain];
            

            NSMutableDictionary* params;
            if (_weibo.loginType == DEFAULT_USER) {
                params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                          _requestToken,@"oauth_token",
                          @"json",@"oauth_callback",
                          @"mobile",@"display",
                          _defaultAccount,@"userId",
                          _defaultPassword,@"passwd",nil];
            }else{
                params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                          _requestToken,@"oauth_token",
                          @"json",@"oauth_callback",
                          @"mobile",@"display",
                          _account,@"userId",
                          _password,@"passwd",nil];
            }
            
            if( _request )
            {
                [_request release];
                _request = nil;
            }
            
            _request = [WBRequest getRequestWithParams:params
                                            httpMethod:@"GET" 
                                          postDataType:WBRequestPostDataType_Normal 
                                              delegate:self 
                                            requestURL:oauthUserAuthorizeURL 
                                      headerFieldsInfo:[NSDictionary dictionaryWithObjectsAndKeys:nil]];
            
            [_request connect];
            [_request retain];
		}
	}
	[string release];
}


- (void)getAccessTokenWithVerifier:(NSString*)verifier
{	
	_waitingUserAuthorize = FALSE;
	NSMutableDictionary* headInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									 _appKey,@"oauth_consumer_key",
									 _requestToken,@"oauth_token",
									 @"HMAC-SHA1",@"oauth_signature_method",
									 [NSString stringWithFormat:@"%.0f",[[NSDate date]timeIntervalSince1970]],@"oauth_timestamp",
									 [NSString GUIDString],@"oauth_nonce",
									 @"1.0",@"oauth_version",
									 verifier,@"oauth_verifier",nil];
	
	NSString* baseString = [WBAuthorize getSignatureBaseStringWithHttpMethod:@"POST" withURL:oauthGetAccessTokenURL withHeadInfo:headInfo];
	NSString* keyString = [NSString stringWithFormat:@"%@&%@",[_appSecret URLEncodedString],[_requestSecret URLEncodedString]];
	NSString* signatureString = [[baseString HMACSHA1EncodedDataWithKey:keyString]base64EncodedString];
	
	[headInfo setObject:signatureString forKey:@"oauth_signature"];
	
	if( _request )
	{
		[_request release];
		_request = nil;
	}
	_request = [WBRequest getRequestWithParams:nil
									httpMethod:@"POST" 
								  postDataType:WBRequestPostDataType_Normal 
									  delegate:self 
									requestURL:oauthGetAccessTokenURL 
							  headerFieldsInfo:[NSDictionary dictionaryWithObject:[WBAuthorize stringFromDictionaryForOAuthRequestHeadField:headInfo] forKey:@"Authorization"]];
	
	[_request connect];
	[_request retain];
}

- (void)gettingAccessTokenSuccessWithData:(NSData*)data
{
	NSString* string = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
	if( [string rangeOfString:@"error"].location == NSNotFound )
	{
		NSDictionary* info = [WBAuthorize infoFromOAuthRequestReturnString:string];
		if( [info count] >= 3 )
		{
			NSString* userID = [info objectForKey:@"user_id"];
			NSString* accessToken = [info objectForKey:@"oauth_token"];
			NSString* accessSecret = [info objectForKey:@"oauth_token_secret"];
			if (_weibo.loginType == DEFAULT_USER) {
                if( _delegate && [(NSObject*)_delegate respondsToSelector:@selector(authorizeDufaultSuccess:userID:oauthToken:oauthSecret:)] )
                    [_delegate authorizeDufaultSuccess:self userID:userID oauthToken:accessToken oauthSecret:accessSecret];
            }else{
                if( _delegate && [(NSObject*)_delegate respondsToSelector:@selector(authorizeSuccess:userID:oauthToken:oauthSecret:)] )
                    [_delegate authorizeSuccess:self userID:userID oauthToken:accessToken oauthSecret:accessSecret];
            }
		}
	}
	[string release];
}

//**************************************************************************************************//
// MARK: by nasa added for login
- (void)gettingVerifierSuccessWithData:(NSData*)data
{
	NSString* string = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
	if( [string rangeOfString:@"error"].location == NSNotFound )
	{
		NSDictionary* info = [string JSONValue];
		if( [info count] >= 2 )
		{
			NSString* verifier = [info objectForKey:@"oauth_verifier"];
			
            [self getAccessTokenWithVerifier:verifier];
		}
	}
	[string release];
}
//**************************************************************************************************//

- (void)request:(WBRequest *)request didLoadRawResponse:(NSData *)data
{
	if( [request.url isEqualToString:oauthGetRequestTokenURL] )
	{
		[self gettingRequestTokenSuccessWithData:data];
	}
	
	if( [request.url isEqualToString:oauthGetAccessTokenURL] )
	{
		[self gettingAccessTokenSuccessWithData:data];
	}
    // MARK: by nasa added for login
	if( [request.url isEqualToString:oauthUserAuthorizeURL] )
	{
		[self gettingVerifierSuccessWithData:data];
	}
}

- (void)request:(WBRequest *)request didFailWithError:(NSError *)error
{
	NSError* localError = nil;
	if( [request.url isEqualToString:oauthGetRequestTokenURL] )
	{
		if( [[error domain] isEqualToString:domainWeiboError] && [error code]==CodeWeiboError_SDK )
			return;
		
		localError = [NSError errorWithDomain:domainWeiboError 
										 code:CodeWeiboError_SDK 
									 userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%d",CodeWeiboSDKError_GetRequestError] forKey:keyCodeWeiboSDKError]];
	}
	
	if( [request.url isEqualToString:oauthGetAccessTokenURL] )
	{
		if( [[error domain] isEqualToString:domainWeiboError] && [error code]==CodeWeiboError_SDK )
			return;
		
		localError = [NSError errorWithDomain:domainWeiboError 
										 code:CodeWeiboError_SDK 
									 userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%d",CodeWeiboSDKError_GetAccessError] forKey:keyCodeWeiboSDKError]];
	}
	
	if( [_delegate respondsToSelector:@selector(authorizeFailed:withError:)] )
	{
		[_delegate authorizeFailed:self withError:localError];
	}
}
@end


@implementation WBRequest (WBAuthorize)
+ (WBRequest*)getAuthorizeRequestWithParams:(NSMutableDictionary *) params
								 httpMethod:(NSString *) httpMethod 
							   postDataType:(WBRequestPostDataType) postDataType					//only valid when http method is "POST"
								   delegate:(id<WBRequestDelegate>)delegate
								 requestURL:(NSString *) url 
						   headerFieldsInfo:(NSDictionary*)headerFieldsInfo 
									 appKey:(NSString*)appkey 
								  appSecret:(NSString*)appSecret
								accessToken:(NSString*)token 
							   accessSecret:(NSString*)secret
{
	NSMutableDictionary* headInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									 appkey,@"oauth_consumer_key",
									 [NSString GUIDString],@"oauth_nonce",
									 @"HMAC-SHA1",@"oauth_signature_method",
									 token,@"oauth_token",
									 [NSString stringWithFormat:@"%.0f",[[NSDate date]timeIntervalSince1970]],@"oauth_timestamp",
									 @"1.0",@"oauth_version",nil];
	
	NSMutableDictionary* infoForSignture = [NSMutableDictionary dictionaryWithDictionary:headInfo];
	for (id key in [params keyEnumerator]) 
	{
		NSObject* value = [params valueForKey:key];
		if( [value isKindOfClass:[NSString class]] )
		{
			[infoForSignture setObject:value forKey:key];
		}
	}
	
	NSString* baseString = [WBAuthorize getSignatureBaseStringWithHttpMethod:httpMethod withURL:url withHeadInfo:infoForSignture];
	NSString* keyString = [NSString stringWithFormat:@"%@&%@",[appSecret URLEncodedString],[secret URLEncodedString]];
	NSString* signatureString = [[baseString HMACSHA1EncodedDataWithKey:keyString]base64EncodedString];
	[headInfo setObject:signatureString forKey:@"oauth_signature"];
	
	NSMutableDictionary* dictionary = [NSDictionary dictionaryWithObject:[WBAuthorize stringFromDictionaryForOAuthRequestHeadField:headInfo] forKey:@"Authorization"];
	[dictionary addEntriesFromDictionary:headerFieldsInfo];
	
	return [WBRequest getRequestWithParams:params
								httpMethod:httpMethod 
							  postDataType:postDataType 
								  delegate:delegate 
								requestURL:url 
						  headerFieldsInfo:dictionary];
}


@end
