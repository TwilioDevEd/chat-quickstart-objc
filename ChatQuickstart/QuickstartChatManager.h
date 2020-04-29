//
//  QuickstartChatManager.h
//  ChatQuickstart
//
//  Created by Jeffrey Linwood on 3/21/20.
//  Copyright © 2020 Twilio, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TCHResult;
@class TCHMessage;

NS_ASSUME_NONNULL_BEGIN

@protocol QuickstartChatManagerDelegate <NSObject>
- (void) receivedNewMessage;
@end

@interface QuickstartChatManager : NSObject
- (NSOrderedSet*) messages;
- (void) setDelegate:(id <QuickstartChatManagerDelegate>)delegate;
- (void) login:(NSString*)identity completionHandler:(void(^)(BOOL success))completionHandler;
- (void) sendMessage:(NSString*)messageText completionHandler:(nonnull void (^)(TCHResult * _Nonnull result, TCHMessage * _Nullable message))completionHandler;
@end

NS_ASSUME_NONNULL_END
