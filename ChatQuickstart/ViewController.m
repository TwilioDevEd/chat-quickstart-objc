//
//  ViewController.m
//  ChatQuickstart
//
//  Created by Jeffrey Linwood, Kevin Whinnery on 11/29/16.
//  Copyright © 2016 Twilio, Inc. All rights reserved.
//

#import "ViewController.h"
#import <TwilioChatClient/TwilioChatClient.h>

#pragma mark - Interface
@interface ViewController () <UITableViewDelegate, UITableViewDataSource, TwilioChatClientDelegate, UITextFieldDelegate>

#pragma mark - IP Messaging Members
@property (strong, nonatomic) NSString *identity;
@property (strong, nonatomic) NSMutableOrderedSet *messages;
@property (strong, nonatomic) TCHChannel *channel;
@property (strong, nonatomic) TwilioChatClient *client;

#pragma mark - UI Elements
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UITextField *textField;

@end

#pragma mark - Implementation

@implementation ViewController

#pragma mark - Lifecycle

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder]) != nil) {
        [self sharedInit];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) != nil) {
        [self sharedInit];
    }
    return self;
}

- (void)sharedInit {
    self.messages = [[NSMutableOrderedSet alloc] init];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set up tableview
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 66.0;
    self.tableView.separatorStyle = UITableViewCellSelectionStyleNone;
    
    // text field
    self.textField.delegate = self;
    
    // Dodge Keyboard when text field is selected
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:self.view.window];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:self.view.window];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:self.view.window];
    
    // Initialize Chat Client
    NSString *identifierForVendor = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *tokenEndpoint = @"http://localhost:3000/token?device=%@";
    NSString *urlString = [NSString stringWithFormat:tokenEndpoint, identifierForVendor];
    
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
                self.identity = tokenResponse[@"identity"];
                [TwilioChatClient chatClientWithToken:tokenResponse[@"token"] properties:nil delegate:self completion:^(TCHResult * _Nonnull result, TwilioChatClient * _Nullable chatClient) {
                    self.client = chatClient;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.navigationItem.prompt = [NSString stringWithFormat:@"Logged in as %@", self.identity];
                    });
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

#pragma mark - UI Helpers
- (void)scrollToBottomMessage {
    if (self.messages.count == 0) {
        return;
    }
    
    int row = (int) [self.tableView numberOfRowsInSection:0] - 1;
    NSIndexPath *bottomMessageIndex = [NSIndexPath indexPathForRow:row
                                                         inSection:0];
    
    [self.tableView scrollToRowAtIndexPath:bottomMessageIndex
                          atScrollPosition:UITableViewScrollPositionBottom
                                  animated:NO];
}

- (void)addMessages:(NSArray<TCHMessage *> *)messages {
    [self.messages addObjectsFromArray:messages];
    [self sortMessages];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
        if (self.messages.count > 0) {
            [self scrollToBottomMessage];
        }
    });
}

- (void)sortMessages {
    [self.messages sortUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"timestamp"
                                                                      ascending:YES]]];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = keyboardFrame.size.height;
    
    self.bottomConstraint.constant = keyboardHeight + 8;
    [self.view setNeedsLayout];
}

- (void)keyboardDidShow:(NSNotification *)notification {
    [self scrollToBottomMessage];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.bottomConstraint.constant = 8;
    [self.view setNeedsLayout];
}

- (IBAction)viewTapped:(id)sender {
    [self.textField resignFirstResponder];
}

#pragma mark - UITableViewDelegate

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessageCell"
                                                            forIndexPath:indexPath];
    TCHMessage *message = [self.messages objectAtIndex:indexPath.row];
    cell.detailTextLabel.text = message.author;
    cell.textLabel.text = message.body;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.text.length == 0) {
        [self.view endEditing:YES];
    } else {
        TCHMessageOptions *messageOptions = [[TCHMessageOptions new] withBody:textField.text];
        textField.text = @"";
        [self.channel.messages sendMessageWithOptions:messageOptions completion:^(TCHResult * _Nonnull result, TCHMessage * _Nullable message) {
            [textField resignFirstResponder];
            if (!result.isSuccessful) {
                NSLog(@"message not sent...");
            }
        }];
    }
    return YES;
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
    [self addMessages:@[message]];
}


@end

