
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol WebViewProxyDelegate <NSObject>

- (void)didStartLoad;
- (void)didFinishLoad;
- (void)didFailLoadWithError:(NSError *)error;

- (BOOL)shouldStartLoadWithRequest:(NSURLRequest *)request;

@end

@interface WebViewProxy : UIView

@property (nullable, weak) id <WebViewProxyDelegate> delegate;

- (void)loadRequest:(NSURLRequest *)request;

@end

NS_ASSUME_NONNULL_END
