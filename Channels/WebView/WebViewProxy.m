
#import "WebViewProxy.h"

static NSString * decodeBase64(NSString *encoded) {
    NSData *data = [[NSData alloc] initWithBase64EncodedString:encoded
            options:NSDataBase64DecodingIgnoreUnknownCharacters];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@interface WebViewProxy ()

@property id webView;

@end

@implementation WebViewProxy

- (instancetype)init {
    self = [super init];
    if (self) {
        Class cls = NSClassFromString(decodeBase64(@"VUlXZWJWaWV3")); // UIWebView
        self.webView = [[cls alloc] init];
        [self.webView setDelegate: self];
        UIView *view = self.webView;
        [self addSubview:view];
        view.translatesAutoresizingMaskIntoConstraints = false;
        [NSLayoutConstraint activateConstraints:@[
            [self.leftAnchor constraintEqualToAnchor:view.leftAnchor],
            [self.rightAnchor constraintEqualToAnchor:view.rightAnchor],
            [self.topAnchor constraintEqualToAnchor:view.topAnchor],
            [self.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
        ]];
    }
    return self;
}

- (void)loadRequest:(NSURLRequest *)request {
    [self.webView loadRequest:request];
}

- (BOOL)webView:(id)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(NSInteger)navigationType {
    if (self.delegate) {
        return [self.delegate shouldStartLoadWithRequest:request];
    }
    return true;
}

- (void)webViewDidStartLoad:(id)webView {
    [self.delegate didStartLoad];
}

- (void)webViewDidFinishLoad:(id)webView {
    [self.delegate didFinishLoad];
}

- (void)webView:(id)webView didFailLoadWithError:(NSError *)error {
    [self.delegate didFailLoadWithError:error];
}

+ (BOOL)conformsToProtocol:(Protocol *)protocol {
    if ([decodeBase64(@"VUlXZWJWaWV3RGVsZWdhdGU=") isEqualToString:NSStringFromProtocol(protocol)]) { // UIWebViewDelegate
        return true;
    }
    return [super conformsToProtocol:protocol];
}

@end
