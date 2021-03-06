#import "VMHUDView.h"
#import "VMHUDWindow.h"
#import "MTMaterialView.h"
#import <objc/runtime.h>
#import <MRYIPCCenter/MRYIPCCenter.h>

@interface VMHUDView  (){
    CGPoint _originalPoint;//之前的位置
}
@property (strong, nonatomic) UIImpactFeedbackGenerator*feedback;
@end
@implementation VMHUDView
-(instancetype)initWithFrame:(CGRect)frame{
	self=[super initWithFrame:frame];
	if(!self)return self;

	self.clipsToBounds = YES;
	self.layer.cornerRadius = 14.;
    self.curScale=1.;

    // credits to https://github.com/Muirey03/13HUD/blob/master/MRYHUDView.xm#L69
	// create blurred background for slider:
	UIBlurEffect* blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
	UIVisualEffectView* blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
	blurView.frame = self.bounds;
	blurView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
	[self addSubview:blurView];
#if TARGET_OS_SIMULATOR
    NSArray* bundles = @[
        @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/MaterialKit.framework",
        @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/MaterialKit.framework"
    ];
#else
    NSArray* bundles = @[
        @"/System/Library/PrivateFrameworks/MaterialKit.framework",
    ];
#endif
	

	for (NSString* bundlePath in bundles)
	{
		NSBundle* bundle = [NSBundle bundleWithPath:bundlePath];
		if (!bundle.loaded)
			[bundle load];
	}
    MTMaterialView* mtBgView,*mtSliderView;
    if(@available(iOS 13.0, *)) {
        mtBgView=[objc_getClass("MTMaterialView") materialViewWithRecipe:4 configuration:2 initialWeighting:1];
        mtSliderView=[objc_getClass("MTMaterialView") materialViewWithRecipe:4 configuration:3 initialWeighting:1] ;
    }
    else if(@available(iOS 11.0, *)){
        mtBgView=[objc_getClass("MTMaterialView") materialViewWithRecipe:4 options:3 initialWeighting:1];
        mtSliderView=[objc_getClass("MTMaterialView") materialViewWithRecipe:4 options:32 initialWeighting:1] ;
    }
	else{
        mtBgView=[objc_getClass("MTMaterialView") materialViewWithStyleOptions:4 materialSettings:nil captureOnly:NO];
        mtSliderView=[objc_getClass("MTMaterialView") materialViewWithStyleOptions:1 materialSettings:nil captureOnly:NO];
    }
	[mtBgView setFrame:self.bounds];
	[self addSubview:mtBgView];

	_clippingView=[[UIView alloc] initWithFrame:CGRectMake(0,0,self.bounds.size.width,self.bounds.size.height)];
	_clippingView.clipsToBounds = YES;
	[self addSubview:_clippingView];

	
	[mtSliderView setFrame:self.bounds];
	[_clippingView addSubview:mtSliderView];

	UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    [self addGestureRecognizer:longPress];
    longPress.minimumPressDuration=0;

    

	return self;

}
-(void)initScale{
    NSNumber*scaleNumber=[self readConf];
    if(scaleNumber){
        double scale=[scaleNumber doubleValue];
        [_clippingView setFrame:CGRectMake(_clippingView.frame.origin.x,
                                            _clippingView.frame.size.height*(1.-scale),
                                            _clippingView.frame.size.width,
                                            _clippingView.frame.size.height
            )];
        _curScale=scale;
    }
}
-(NSNumber*)readConf{
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if(!prefs)prefs=[NSMutableDictionary new];
    return prefs[_bundleID];
}
-(void)saveConf:(NSNumber*)scale{
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if(!prefs)prefs=[NSMutableDictionary new];
    prefs[_bundleID]=scale;
    [prefs writeToFile:kPrefPath atomically:YES];
}
- (void)longPress:(UILongPressGestureRecognizer *)longPress{
    //获取当前位置
    CGPoint currentPosition = [longPress locationInView:self];
    if (longPress.state == UIGestureRecognizerStateBegan) {
        _originalPoint = currentPosition;
        _feedback=[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [_feedback impactOccurred];
    }else if(longPress.state == UIGestureRecognizerStateChanged){
        //偏移量(当前坐标 - 起始坐标 = 偏移量)
        // CGFloat offsetX = currentPosition.x - _originalPoint.x;
        CGFloat offsetY = currentPosition.y - _originalPoint.y;
        _originalPoint = currentPosition;

        CGFloat newY=MIN(MAX(_clippingView.frame.origin.y+offsetY,0),_clippingView.frame.size.height);
        CGFloat scale=1.-newY/_clippingView.frame.size.height;
        // NSLog(@"Scale:%lf",scale);
        if(fabs(scale-_curScale)>1./16.||scale==0.){
        	_curScale=scale;
            // NSLog(@"newScale:%lf",_curScale);
            [_client callExternalMethod:@selector(setVolume:)withArguments:@{@"curScale" : @(_curScale)} completion:^(id ret){}];
        }

        [_clippingView setFrame:CGRectMake(_clippingView.frame.origin.x,
        									newY,
        									_clippingView.frame.size.width,
        									_clippingView.frame.size.height)];


    }else if (longPress.state == UIGestureRecognizerStateEnded){
        [_feedback impactOccurred];
        _feedback=nil;
        [self saveConf:[NSNumber numberWithDouble:1.-_clippingView.frame.origin.y/_clippingView.frame.size.height]];
    }
}
@end