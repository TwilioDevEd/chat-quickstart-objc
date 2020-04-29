//
//  ViewController.m
//  ChatQuickstart
//
//  Created by Jeffrey Linwood, Kevin Whinnery on 11/29/16.
//  Copyright © 2016 Twilio, Inc. All rights reserved.
//

#import "ViewController.h"

#import "QuickstartChatManager.h"

#import <TwilioChatClient/TwilioChatClient.h>



#pragma mark - Interface
@interface ViewController () <UITableViewDelegate, UITableViewDataSource,
    TwilioChatClientDelegate, UITextFieldDelegate, QuickstartChatManagerDelegate>

#pragma mark - Twilio Chat Members
@property (strong, nonatomic) NSString *identity;
@property (strong, nonatomic) QuickstartChatManager *chatManager;

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
    self.chatManager = [QuickstartChatManager new];
    self.chatManager.delegate = self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set up the user's identity - typically after they log in
    self.identity = @"USER_IDENTITY";
    
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
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    __weak typeof(self) weakSelf = self;
    [self.chatManager login:self.identity completionHandler:^(BOOL success) {
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.navigationItem.prompt = [NSString stringWithFormat:@"Logged in as %@", weakSelf.identity];
            });
        }
    }];
}

#pragma mark - Quickstart Chat Manager Delegate
- (void) receivedNewMessage {
    dispatch_async(dispatch_get_main_queue(), ^{
       [self.tableView reloadData];
       if (self.chatManager.messages.count > 0) {
           [self scrollToBottomMessage];
       }
    });
}

#pragma mark - UI Helpers
- (void)scrollToBottomMessage {
    if (self.chatManager.messages.count == 0) {
        return;
    }
    
    int row = (int) [self.tableView numberOfRowsInSection:0] - 1;
    NSIndexPath *bottomMessageIndex = [NSIndexPath indexPathForRow:row
                                                         inSection:0];
    
    [self.tableView scrollToRowAtIndexPath:bottomMessageIndex
                          atScrollPosition:UITableViewScrollPositionBottom
                                  animated:NO];
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
    TCHMessage *message = [self.chatManager.messages objectAtIndex:indexPath.row];
    cell.detailTextLabel.text = message.author;
    cell.textLabel.text = message.body;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.chatManager.messages.count;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.text.length == 0) {
        [self.view endEditing:YES];
    } else {
        [self.chatManager sendMessage:textField.text completionHandler:^(TCHResult* result, TCHMessage* message) {
            dispatch_async(dispatch_get_main_queue(), ^{
                textField.text = @"";
                [textField resignFirstResponder];
                if (!result.isSuccessful) {
                    NSLog(@"message not sent...");
                }
            });
        }];
        
    }
    return YES;
}


@end

