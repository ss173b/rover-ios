//
//  RXDetailViewController.m
//  Pods
//
//  Created by Ata Namvari on 2015-01-30.
//
//

#import "RXDetailViewController.h"
#import "RXTransition.h"
#import "RXBlockView.h"
#import "RVViewDefinition.h"
#import "RVBlock.h"
#import "RVHeaderBlock.h"

#import <SDWebImage/UIImageView+WebCache.h>

@interface RXDetailViewController ()

@property (nonatomic, strong) RXTransition *transitionManager;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIView *titleBar;
@property (nonatomic, strong) UIView *backgroundView;


@property (nonatomic, strong) NSLayoutConstraint *containerBarBottomConstraint;


@end

@implementation RXDetailViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _transitionManager = [[RXTransition alloc] initWithParentViewController:self];
        self.transitioningDelegate = _transitionManager;
        self.modalPresentationStyle = UIModalPresentationCustom;
    }
    return self;
}

- (instancetype)initWithViewDefinition:(RVViewDefinition *)viewDefinition {
    self = [self init];
    if (self) {
        self.viewDefinition = viewDefinition;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _titleBar = [UIView new];
    _titleBar.translatesAutoresizingMaskIntoConstraints = NO;
    _titleBar.backgroundColor = [UIColor clearColor];
    _titleBar.userInteractionEnabled = YES;
    
    _scrollView = [UIScrollView new];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.scrollEnabled = YES;
    _scrollView.backgroundColor = [UIColor clearColor];
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.delegate = _transitionManager;
    
    _containerView = [UIView new];
    _containerView.translatesAutoresizingMaskIntoConstraints = NO;
    _containerView.backgroundColor = [UIColor clearColor];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(_scrollView,_titleBar,_containerView);
    
    [_scrollView addSubview:_containerView];
    [self.view addSubview:_scrollView];
    [self.view addSubview:_titleBar];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_containerView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_containerView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
    [_scrollView addConstraint:[NSLayoutConstraint constraintWithItem:_containerView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_scrollView attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    //[self.view addConstraint:[NSLayoutConstraint constraintWithItem:_containerView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    _containerBarBottomConstraint = [NSLayoutConstraint constraintWithItem:_containerView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_scrollView attribute:NSLayoutAttributeBottom multiplier:1 constant:0];
    [self.view addConstraint:_containerBarBottomConstraint];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[_titleBar]|" options:0 metrics:nil views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[_scrollView]|" options:0 metrics:nil views:views]];
    
    _titleBarTopConstraint = [NSLayoutConstraint constraintWithItem:_titleBar attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:0];
    [self.view addConstraint:_titleBarTopConstraint];
    
    _scrollViewHeightConstraint = [NSLayoutConstraint constraintWithItem:_scrollView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeHeight multiplier:1 constant:0];
    [self.view addConstraint:_scrollViewHeightConstraint];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_scrollView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];

    
    [self loadViewDefinition];
}

- (void)loadViewDefinition {
    [_containerView.subviews enumerateObjectsUsingBlock:^(UIView *subview, NSUInteger idx, BOOL *stop) {
        [subview removeFromSuperview];
    }];
    [_viewDefinition.blocks enumerateObjectsUsingBlock:^(RVBlock *block, NSUInteger idx, BOOL *stop) {
        RXBlockView *blockView = [[RXBlockView alloc] initWithBlock:block];
        if ([block class] == [RVHeaderBlock class]) {
            blockView.userInteractionEnabled = YES;
            [self addHeaderBlockView:blockView];
            
            // move this somewhere else
            _scrollViewHeightConstraint.constant = -[block heightForWidth:self.view.frame.size.width];
            
        } else {
            [self addBlockView:blockView];
        }
    }];
    // TODO: move this stuff out
    
    
    // UIScrollView AutoLayout ContentSize Constraint
    UIView *lastBlock = _containerView.subviews[_containerView.subviews.count - 1];
    [_containerView addConstraint:[NSLayoutConstraint constraintWithItem:lastBlock attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_containerView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    
    
    // UIScrollView Background
    [self addBackgroundView];
    
    
    // titlebar height bug
    UIView *lastTitleBlock = _titleBar.subviews[_titleBar.subviews.count - 1];
    if (lastTitleBlock) {
        [_titleBar addConstraint:[NSLayoutConstraint constraintWithItem:_titleBar attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:lastTitleBlock attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    }
}

- (void)addBackgroundView {
    _backgroundView = [UIView new];
    _backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    _backgroundView.backgroundColor = _viewDefinition.backgroundColor;
    
    UIView *firstBlock = _containerView.subviews[0];
    
    [_containerView addSubview:_backgroundView];
    [_containerView sendSubviewToBack:_backgroundView];
    [_containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[_backgroundView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_backgroundView)]];
    [_containerView addConstraint:[NSLayoutConstraint constraintWithItem:_backgroundView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:firstBlock attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_backgroundView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    
    // Background Image
    if (_viewDefinition.backgroundImageURL) {
        [self setBackgroundImageWithURL:_viewDefinition.backgroundImageURL contentMode:_viewDefinition.backgroundContentMode];
    }
}

- (void)setBackgroundImageWithURL:(NSURL *)url contentMode:(RVBackgroundContentMode)contentmode {
    __weak UIView *weakContainerView = _backgroundView;
    if (contentmode == RVBackgroundContentModeTile) {
        [[SDWebImageManager sharedManager] downloadImageWithURL:url options:0 progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            weakContainerView.backgroundColor = [UIColor colorWithPatternImage:image];
        }];
    } else {
        UIImageView *backgroundImageView = [UIImageView new];
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
        backgroundImageView.contentMode = UIViewContentModeFromRVBackgroundContentMode(contentmode);
        [backgroundImageView sd_setImageWithURL:url];
        
        [weakContainerView addSubview:backgroundImageView];
        
        NSDictionary *views = NSDictionaryOfVariableBindings(backgroundImageView);
        
        [weakContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[backgroundImageView]|" options:0 metrics:nil views:views]];
        [weakContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[backgroundImageView]|" options:0 metrics:nil views:views]];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)configureLayoutForBlockView:(RXBlockView *)blockView
{
    id lastBlockView = _containerView.subviews.count > 1 ? _containerView.subviews[_containerView.subviews.count - 2] : nil;
    [_containerView addConstraints:[RXBlockView constraintsForBlockView:blockView withPreviousBlockView:lastBlockView inside:_containerView]];
    
    // Height constraint
    [_containerView addConstraint:[NSLayoutConstraint constraintWithItem:blockView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1 constant:[blockView.block heightForWidth:self.view.frame.size.width]]];
}

- (void)configureHeaderLayoutForBlockView:(RXBlockView *)blockView {
    id lastHeaderBlockView = _titleBar.subviews.count > 1 ? _titleBar.subviews[_titleBar.subviews.count - 2] : nil;
    [_titleBar addConstraints:[RXBlockView constraintsForBlockView:blockView withPreviousBlockView:lastHeaderBlockView inside:_titleBar]];
 
    // Height constraint
    [_titleBar addConstraint:[NSLayoutConstraint constraintWithItem:blockView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:0 multiplier:1 constant:[blockView.block heightForWidth:self.view.frame.size.width]]];
}

- (void)addBlockView:(RXBlockView *)blockView {
    [_containerView addSubview:blockView];
    [self configureLayoutForBlockView:blockView];
}

- (void)addHeaderBlockView:(RXBlockView *)blockView {
    [_titleBar addSubview:blockView];
    [self configureHeaderLayoutForBlockView:blockView];
}

@end
