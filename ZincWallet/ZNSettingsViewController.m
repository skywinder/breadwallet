//
//  ZNSettingsViewController.m
//  ZincWallet
//
//  Created by Aaron Voisine on 6/11/13.
//  Copyright (c) 2013 zinc. All rights reserved.
//

#import "ZNSettingsViewController.h"
#import "ZNSeedViewController.h"
#import "ZNWallet.h"

@interface ZNSettingsViewController ()

@property (nonatomic, strong) NSArray *transactions;
@property (nonatomic, strong) id balanceObserver;

@end

@implementation ZNSettingsViewController

//XXX need setting for denomination (BTC, mBTC or uBTC)
//XXX also for local currency, and exchange rate source

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;

    ZNWallet *w = [ZNWallet sharedInstance];
    
    w.format.minimumFractionDigits = w.balance > 0 ? 1 : w.format.maximumFractionDigits;
    self.navigationItem.title = [w stringForAmount:w.balance];
    w.format.minimumFractionDigits = 0;
    
    self.balanceObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:walletBalanceNotification object:nil queue:nil
        usingBlock:^(NSNotification *note) {
            ZNWallet *w = [ZNWallet sharedInstance];
            
            w.format.minimumFractionDigits = w.balance > 0 ? 1 : w.format.maximumFractionDigits;
            self.navigationItem.title = [w stringForAmount:w.balance];
            w.format.minimumFractionDigits = 0;
            
            self.transactions = [ZNWallet sharedInstance].recentTransactions;
            
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
             withRowAnimation:UITableViewRowAnimationAutomatic];
        }];
}

- (void)viewWillUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver:self.balanceObserver];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.transactions = [ZNWallet sharedInstance].recentTransactions;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBAction

- (IBAction)done:(id)sender
{
    [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    switch (section) {
        case 0: return self.transactions.count ? self.transactions.count : 1;
        case 1: return 2;
        case 2: return 1;
        default: NSAssert(FALSE, @"[%s %s] line %d: unkown section %d", object_getClassName(self), sel_getName(_cmd),
                          __LINE__, section);
    }

    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *disclosureIdent = @"ZNDisclosureCell", *transactionIdent = @"ZNCustomTransactionCell",
                    *actionIdent = @"ZNActionCell";
    UITableViewCell *cell = nil;
    __block UILabel *textLabel, *detailTextLabel;
    
    // Configure the cell...
    switch (indexPath.section) {
        case 0:
            cell = [tableView dequeueReusableCellWithIdentifier:transactionIdent];
            textLabel = (id)[cell viewWithTag:1];
            detailTextLabel = (id)[cell viewWithTag:2];

            if (! self.transactions.count) {
                textLabel.text = @"no transactions";
                textLabel.textColor = [UIColor lightGrayColor];
                textLabel.textAlignment = UITextAlignmentCenter;
                detailTextLabel.text = nil;
            }
            else {
                ZNWallet *w = [ZNWallet sharedInstance];
                NSDictionary *tx = self.transactions[indexPath.row];
                __block uint64_t received = 0, spent = 0;

                [tx[@"inputs"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if (obj[@"prev_out"][@"addr"] && [w containsAddress:obj[@"prev_out"][@"addr"]]) {
                        spent += [obj[@"prev_out"][@"value"] unsignedLongLongValue];
                    }
                }];

                __block BOOL withinWallet = spent > 0 ? YES : NO;
                
                [tx[@"out"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if (obj[@"addr"] && [w containsAddress:obj[@"addr"]]) {
                        received += [obj[@"value"] unsignedLongLongValue];
                        if (spent == 0) detailTextLabel.text = [@"to: " stringByAppendingString:obj[@"addr"]];
                    }
                    else if (spent > 0) {
                        if (obj[@"addr"]) detailTextLabel.text = [@"to: " stringByAppendingString:obj[@"addr"]];
                        withinWallet = NO;
                    }
                }];
                
                if (withinWallet) {
                    textLabel.text = [w stringForAmount:spent];
                    detailTextLabel.text = @"moved within wallet";
                    textLabel.textAlignment = UITextAlignmentLeft;
                }
                else if (spent > 0) {
                    textLabel.text = [NSString stringWithFormat:@"(%@)", [w stringForAmount:spent - received]];
                    textLabel.textAlignment = UITextAlignmentRight;
                }
                else {
                    textLabel.text = [w stringForAmount:received];
                    textLabel.textAlignment = UITextAlignmentLeft;
                }
                
                if (! tx[@"block_height"]) {
                    if (spent > 0) {
                        textLabel.text = [@"unconfirmed " stringByAppendingString:textLabel.text];
                    }
                    else textLabel.text = [textLabel.text stringByAppendingString:@" unconfirmed"];
                }
                
                textLabel.textColor = [UIColor darkGrayColor];
                if (! detailTextLabel.text) detailTextLabel.text = @"can't decode payment address";
            }
            break;
            
        case 1:
            cell = [tableView dequeueReusableCellWithIdentifier:disclosureIdent];
            
            switch (indexPath.row) {
                case 0:
//                    cell.textLabel.text = @"safety tips";
//                    break;
//
//                case 1:
                    cell.textLabel.text = @"backup phrase";
                    cell.userInteractionEnabled = YES;
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    break;
                    
                case 1:
                    cell.textLabel.text = nil;
                    cell.userInteractionEnabled = NO;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
            
                default: NSAssert(FALSE, @"[%s %s] line %d: unkown indexPath.row %d", object_getClassName(self),
                                  sel_getName(_cmd), __LINE__, indexPath.row);
            }
            break;
            
        case 2:
            cell = [tableView dequeueReusableCellWithIdentifier:actionIdent];

            switch (indexPath.row) {
                case 0:
                    //cell.contentView.backgroundColor =
                    //    [UIColor colorWithPatternImage:[UIImage imageNamed:@"redgradient.png"]];
                    cell.textLabel.text = @"start or restore new wallet";
                    cell.textLabel.textColor = [UIColor redColor];
                    cell.textLabel.shadowColor = [UIColor clearColor];
                    cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
                    cell.selectedBackgroundView.backgroundColor =
                        [UIColor colorWithPatternImage:[UIImage imageNamed:@"redgradient.png"]];
                    break;
                                        
                default:
                    NSAssert(FALSE, @"[%s %s] line %d: unkown indexPath.row %d", object_getClassName(self),
                             sel_getName(_cmd), __LINE__, indexPath.row);
            }
            break;
            
        default:
            NSAssert(FALSE, @"[%s %s] line %d: unkown indexPath.section %d", object_getClassName(self),
                     sel_getName(_cmd), __LINE__, indexPath.section);
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0: return @"recent transactions";
        case 1: return @"settings";
        case 2: return @"caution ⇣";
        default: NSAssert(FALSE, @"[%s %s] line %d: unkown section %d", object_getClassName(self), sel_getName(_cmd),
                          __LINE__, section);
    }
    
    return nil;
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat h;
    
    switch (indexPath.section) {
        case 0:
            return 60;

        case 1:
            switch (indexPath.row) {
                case 0:
                    return 44;

                case 1:
                    h = tableView.frame.size.height - 22*3 - self.navigationController.navigationBar.frame.size.height -
                        (self.transactions.count ? self.transactions.count*60 : 60);
                    return h > 0 ? h : 0;

                default:
                    NSAssert(FALSE, @"[%s %s] line %d: unkown indexPath.row %d", object_getClassName(self),
                             sel_getName(_cmd), __LINE__, indexPath.row);
            }
            return 44;
            
        case 2:
            return 44;

        default:
            NSAssert(FALSE, @"[%s %s] line %d: unkown indexPath.section %d", object_getClassName(self),
                     sel_getName(_cmd), __LINE__, indexPath.section);
    }
    
    return 44;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 22.0)];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, self.view.frame.size.width - 20, 22.0)];;
    
    l.text = [self tableView:tableView titleForHeaderInSection:section];
    l.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:15];
    l.backgroundColor = [UIColor clearColor];
    l.textColor = [UIColor whiteColor];
    l.shadowColor = [UIColor lightGrayColor];
    l.shadowOffset = CGSizeMake(0.0, 1.0);
    
    v.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.9];
    [v addSubview:l];
    
    return v;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.

    //XXX should have some option to generate a new wallet and sweep old balance if backup may be compromized

    switch (indexPath.section) {
        case 0:
            //XXX show transaction details
            break;
            
        case 1:
            switch (indexPath.row) {
                case 0:
//                    //XXX show safety tips
//                    [[[UIAlertView alloc] initWithTitle:nil message:@"Don't eat yellow snow." delegate:self
//                      cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
//                    break;
//                    
//                case 1:
                    [[[UIAlertView alloc] initWithTitle:@"WARNING" message:@"DO NOT let anyone see your backup phrase "
                      "or they can spend your bitcoins." delegate:self cancelButtonTitle:@"cancel"
                      otherButtonTitles:@"show", nil] show];
                    break;
                    
                default:
                    NSAssert(FALSE, @"[%s %s] line %d: unkown indexPath.row %d", object_getClassName(self),
                             sel_getName(_cmd), __LINE__, indexPath.row);
            }
            break;
            
        // section 2 is handled in storyboard
        case 2:
            break;
            
        default:
            NSAssert(FALSE, @"[%s %s] line %d: unkown indexPath.section %d", object_getClassName(self),
                     sel_getName(_cmd), __LINE__, indexPath.section);
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == alertView.cancelButtonIndex) {
        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
        return;
    }
    
    ZNSeedViewController *c = [self.storyboard instantiateViewControllerWithIdentifier:@"ZNSeedViewController"];
    [self.navigationController pushViewController:c animated:YES];
}

@end
