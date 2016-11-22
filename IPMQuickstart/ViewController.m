//
//  ViewController.m
//  IPMQuickstart
//
//  Created by Kevin Whinnery on 12/9/15.
//  Copyright © 2015 Twilio. All rights reserved.
//

#import <TwilioChatClient/TwilioChatClient.h>
#import "ViewController.h"

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
  
  // Initialize IP Messaging Client
  NSString *identifierForVendor = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
  NSString *tokenEndpoint = @"http://localhost:8000/token.php?device=%@";
  NSString *urlString = [NSString stringWithFormat:tokenEndpoint, identifierForVendor];
  
  // Make JSON request to server
  NSData *jsonResponse = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlString]];
    
  if (jsonResponse) {
    NSError *jsonError;
    NSDictionary *tokenResponse = [NSJSONSerialization JSONObjectWithData:jsonResponse
                                                                  options:kNilOptions
                                                                    error:&jsonError];
    // Handle response from server
    if (!jsonError) {
      self.identity = tokenResponse[@"identity"];
      self.client = [TwilioChatClient chatClientWithToken:tokenResponse[@"token"] properties:nil delegate:self];
        
     
      self.navigationItem.prompt = [NSString stringWithFormat:@"Logged in as %@", self.identity];
    } else {
      NSLog(@"ViewController viewDidLoad: error parsing token from server");
    }
  } else {
      NSLog(@"ViewController viewDidLoad: error fetching token from server");
  }
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
    TCHMessage *message = [self.channel.messages createMessageWithBody:textField.text];
    textField.text = @"";
    [self.channel.messages sendMessage:message completion:^(TCHResult *result) {
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
synchronizationStatusChanged:(TCHClientSynchronizationStatus)status {
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
