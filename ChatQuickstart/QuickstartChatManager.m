//
//  QuickstartChatManager.m
//  ChatQuickstart
//
//  Created by Jeffrey Linwood on 3/21/20.
//  Copyright © 2020 Twilio, Inc. All rights reserved.
//

#import "QuickstartChatManager.h"

#import "ChatConstants.h"

#import <TwilioChatClient/TwilioChatClient.h>

@interface QuickstartChatManager () <TwilioChatClientDelegate>
@property (strong, nonatomic) NSMutableOrderedSet *messages;
@property (strong, nonatomic) TCHChannel *channel;
@property (strong, nonatomic) TwilioChatClient *client;
@property (strong, nonatomic) NSString *identity;
@property (weak, nonatomic) id <QuickstartChatManagerDelegate> delegate;
@end

@implementation QuickstartChatManager

- (instancetype)init {
    if (self = [super init]) {
        self.messages = [NSMutableOrderedSet new];
    }
    return self;
}

- (void) sendMessage:(NSString*)messageText completionHandler:(nonnull void (^)(TCHResult * _Nonnull, TCHMessage * _Nullable))completionHandler {
    TCHMessageOptions *messageOptions = [[TCHMessageOptions new] withBody:messageText];
    [self.channel.messages sendMessageWithOptions:messageOptions completion:^(TCHResult * _Nonnull result, TCHMessage * _Nullable message) {
        completionHandler(result, message);
    }];
}

- (void) login:(NSString*)identity completionHandler:(void(^)(BOOL))completionHandler {
    
    // store identity to use when access tokens need to refresh
    self.identity = identity;
    
    __weak typeof(self) weakSelf = self;
    [self retrieveToken:identity completionHandler:^(BOOL success, NSString *token) {
        [TwilioChatClient chatClientWithToken:token properties:nil delegate:self completion:^(TCHResult * _Nonnull result, TwilioChatClient * _Nullable chatClient) {
                           weakSelf.client = chatClient;
                           completionHandler(result.isSuccessful);
        }];
    }];
    
   
}

- (void) retrieveToken:(NSString*)identity completionHandler:(void(^)(BOOL success, NSString* token))completionHandler {

    NSString *urlString = [NSString stringWithFormat:TOKEN_URL, identity];
    
    // Make JSON request to server
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
           if (data) {
               NSError *jsonError;
               NSDictionary *tokenResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                             options:kNilOptions
                                                                               error:&jsonError];
               // Handle response from server
               if (!jsonError) {
                   completionHandler(true, tokenResponse[@"token"]);
                   return;
               } else {
                   NSLog(@"Error parsing token from server");
                   completionHandler(false, nil);
                   return;
               }
           } else {
               NSLog(@"Error fetching token from server");
               completionHandler(false, nil);
               return;
           }
       }];
       [dataTask resume];
}

#pragma mark - Chat Channel/Message helper methods

- (void)sortMessages {
    [_messages sortUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"timestamp"
                                                                      ascending:YES]]];
}

- (void)createChannel {
    [self.client.channelsList createChannelWithOptions:@{
        TCHChannelOptionUniqueName: DEFAULT_CHANNEL_UNIQUE_NAME,
        TCHChannelOptionFriendlyName: DEFAULT_CHANNEL_FRIENDLY_NAME,
        TCHChannelOptionType: @(TCHChannelTypePrivate)
    }
    completion:^(TCHResult *result, TCHChannel *channel) {
        self.channel = channel;
        [self joinChannel];
    }];
}

- (void)joinChannel {
    [self.channel joinWithCompletion:^(TCHResult *result) {
        NSLog(@"joined general channel");
    }];
}

#pragma mark - TwilioChatClientDelegate

- (void)chatClient:(TwilioChatClient *)client
synchronizationStatusUpdated:(TCHClientSynchronizationStatus)status {
    if (status == TCHClientSynchronizationStatusCompleted) {
        [client.channelsList
         channelWithSidOrUniqueName:DEFAULT_CHANNEL_UNIQUE_NAME
                         completion:^(TCHResult *result, TCHChannel *channel) {
            if (channel) {
                self.channel = channel;
                [self joinChannel];
            } else {
                // Create the channel if it hasn't been created yet
                [self createChannel];
            }
        }];
    }
}

- (void)chatClient:(TwilioChatClient *)client channel:(TCHChannel *)channel messageAdded:(TCHMessage *)message {
    [_messages addObject:message];
    [self sortMessages];
    [self.delegate receivedNewMessage];
}

- (void)chatClientTokenWillExpire:(TwilioChatClient *)client {
    [self retrieveToken:self.identity completionHandler:^(BOOL success, NSString *token) {
        if (success) {
            [self.client updateToken:token completion:^(TCHResult * _Nonnull result) {
                if (result.isSuccessful) {
                    NSLog(@"Updated access token on client");
                } else {
                    NSLog(@"Unable to update the access token");
                }
            }];
        }
    }];
}

@end
