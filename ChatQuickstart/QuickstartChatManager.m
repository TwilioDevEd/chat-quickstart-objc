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
    
    // Initialize Chat Client
    NSString *urlString = [NSString stringWithFormat:TOKEN_URL, identity];
    
    // Make JSON request to server
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data) {
            NSError *jsonError;
            NSDictionary *tokenResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                          options:kNilOptions
                                                                            error:&jsonError];
            // Handle response from server
            if (!jsonError) {
                [TwilioChatClient chatClientWithToken:tokenResponse[@"token"] properties:nil delegate:self completion:^(TCHResult * _Nonnull result, TwilioChatClient * _Nullable chatClient) {
                    weakSelf.client = chatClient;
                    completionHandler(result.isSuccessful);
                    
                }];
            } else {
                NSLog(@"ViewController viewDidLoad: error parsing token from server");
            }
        } else {
            NSLog(@"ViewController viewDidLoad: error fetching token from server");
        }
    }];
    [dataTask resume];
}

#pragma mark - Helper methods

- (void)sortMessages {
    [self.messages sortUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"timestamp"
                                                                      ascending:YES]]];
}


#pragma mark - TwilioChatClientDelegate

- (void)chatClient:(TwilioChatClient *)client
synchronizationStatusUpdated:(TCHClientSynchronizationStatus)status {
    if (status == TCHClientSynchronizationStatusCompleted) {
        NSString *defaultChannel = @"general";
        
        [client.channelsList channelWithSidOrUniqueName:defaultChannel completion:^(TCHResult *result, TCHChannel *channel) {
            if (channel) {
                self.channel = channel;
                [self.channel joinWithCompletion:^(TCHResult *result) {
                    NSLog(@"joined general channel");
                }];
            } else {
                // Create the general channel (for public use) if it hasn't been created yet
                [client.channelsList createChannelWithOptions:@{
                                                                TCHChannelOptionFriendlyName: @"General Chat Channel",
                                                                TCHChannelOptionType: @(TCHChannelTypePublic)
                                                                }
                                                   completion:^(TCHResult *result, TCHChannel *channel) {
                                                       self.channel = channel;
                                                       [self.channel joinWithCompletion:^(TCHResult *result) {
                                                           [self.channel setUniqueName:defaultChannel completion:^(TCHResult *result) {
                                                               NSLog(@"channel unique name set");
                                                           }];
                                                       }];
                                                   }];
            }
        }];
    }
}


- (void)chatClient:(TwilioChatClient *)client channel:(TCHChannel *)channel messageAdded:(TCHMessage *)message {
    [self.messages addObject:message];
    [self sortMessages];
    [self.delegate receivedNewMessage];
}

@end
