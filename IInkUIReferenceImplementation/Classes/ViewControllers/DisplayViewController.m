// Copyright MyScript. All right reserved.

#import "DisplayViewController.h"
#import "RenderView.h"
#import "Canvas.h"
#import "OffscreenRenderSurfaces.h"
#import <iink/IINKRenderer.h>

@interface DisplayViewController ()

@property (strong, nonatomic) RenderView *backgroundRenderView;
@property (strong, nonatomic) RenderView *modelRenderView;
@property (strong, nonatomic) RenderView *tempRenderView;
@property (strong, nonatomic) RenderView *captureRenderView;

@property (strong, nonatomic) OffscreenRenderSurfaces *offscreenRenderSurfaces;

@property (nonatomic) BOOL didSetConstraints;

@end

@implementation DisplayViewController

#pragma mark -

- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"view.layer.bounds"];
}

#pragma mark - Life cycle

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:CGRectZero];
    self.view.backgroundColor = [UIColor clearColor];

    self.offscreenRenderSurfaces = [[OffscreenRenderSurfaces alloc] init];
    self.offscreenRenderSurfaces.scale = self.view.contentScaleFactor;
  
    self.backgroundRenderView = [[RenderView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.backgroundRenderView];
    self.backgroundRenderView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundRenderView.backgroundColor = self.view.backgroundColor;
    self.backgroundRenderView.offscreenRenderSurfaces = self.offscreenRenderSurfaces;
    
    self.modelRenderView = [[RenderView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.modelRenderView];
    self.modelRenderView.translatesAutoresizingMaskIntoConstraints = NO;
    self.modelRenderView.backgroundColor = [UIColor clearColor];
    self.modelRenderView.opaque = NO;
    self.modelRenderView.offscreenRenderSurfaces = self.offscreenRenderSurfaces;
    
    self.tempRenderView = [[RenderView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.tempRenderView];
    self.tempRenderView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tempRenderView.backgroundColor = [UIColor clearColor];
    self.tempRenderView.opaque = NO;
    self.tempRenderView.offscreenRenderSurfaces = self.offscreenRenderSurfaces;
    
    self.captureRenderView = [[RenderView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.captureRenderView];
    self.captureRenderView.translatesAutoresizingMaskIntoConstraints = NO;
    self.captureRenderView.backgroundColor = [UIColor clearColor];
    self.captureRenderView.opaque = NO;
    self.captureRenderView.offscreenRenderSurfaces = self.offscreenRenderSurfaces;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.backgroundRenderView.layerType = IINKLayerTypeBackground;
    self.modelRenderView.layerType = IINKLayerTypeModel;
    self.tempRenderView.layerType = IINKLayerTypeTemporary;
    self.captureRenderView.layerType = IINKLayerTypeCapture;
    
    [self addObserver:self forKeyPath:@"view.layer.bounds" options:NSKeyValueObservingOptionNew context:nil];
}

#pragma mark -

- (void)setImageLoader:(ImageLoader *)imageLoader
{
    _imageLoader = imageLoader;
    self.backgroundRenderView.imageLoader = imageLoader;
    self.modelRenderView.imageLoader = imageLoader;
    self.tempRenderView.imageLoader = imageLoader;
    self.captureRenderView.imageLoader = imageLoader;
}

- (void)setRenderer:(IINKRenderer *)renderer
{
    self.backgroundRenderView.renderer = renderer;
    self.modelRenderView.renderer = renderer;
    self.tempRenderView.renderer = renderer;
    self.captureRenderView.renderer = renderer;
}

- (void)refreshViews
{
    [self.backgroundRenderView setNeedsDisplay];
    [self.modelRenderView setNeedsDisplay];
    [self.tempRenderView setNeedsDisplay];
    [self.captureRenderView setNeedsDisplay];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"view.layer.bounds"])
    {
        [self refreshViews];
    }
}

#pragma mark - RenderTargetDelegate

- (void)invalidate:(nonnull IINKRenderer *)renderer layers:(IINKLayerType)layers
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ((layers & IINKLayerTypeBackground) == IINKLayerTypeBackground)
        {
            [self.backgroundRenderView setNeedsDisplay];
        }
        if ((layers & IINKLayerTypeModel) == IINKLayerTypeModel)
        {
            [self.modelRenderView setNeedsDisplay];
        }
        if ((layers & IINKLayerTypeTemporary) == IINKLayerTypeTemporary)
        {
            [self.tempRenderView setNeedsDisplay];
        }
        if ((layers & IINKLayerTypeCapture) == IINKLayerTypeCapture)
        {
            [self.captureRenderView setNeedsDisplay];
        }
    });
}

- (void)invalidate:(nonnull IINKRenderer *)renderer area:(CGRect)rect layers:(IINKLayerType)layers
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ((layers & IINKLayerTypeBackground) == IINKLayerTypeBackground)
        {
            [self.backgroundRenderView setNeedsDisplayInRect:rect];
        }
        if ((layers & IINKLayerTypeModel) == IINKLayerTypeModel)
        {
            [self.modelRenderView setNeedsDisplayInRect:rect];
        }
        if ((layers & IINKLayerTypeTemporary) == IINKLayerTypeTemporary)
        {
            [self.tempRenderView setNeedsDisplayInRect:rect];
        }
        if ((layers & IINKLayerTypeCapture) == IINKLayerTypeCapture)
        {
            [self.captureRenderView setNeedsDisplayInRect:rect];
        }
    });
}

- (uint32_t)createOffscreenRenderSurfaceWithWidth:(int)width height:(int)height alphaMask:(BOOL)alphaMask
{
    CGFloat scale = self.offscreenRenderSurfaces.scale;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(scale * width, scale * height), NO, 1);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGLayerRef buffer = CGLayerCreateWithContext(context, CGSizeMake(scale * width, scale * height), nil);
    UIGraphicsEndImageContext();

    CGContextScaleCTM(CGLayerGetContext(buffer), scale, scale);
    return [self.offscreenRenderSurfaces addSurfaceWithBuffer:buffer];
}

- (void)releaseOffscreenRenderSurface:(uint32_t)surfaceId
{
    [self.offscreenRenderSurfaces releaseSurfaceForId:surfaceId];
}

- (nonnull id<IINKICanvas>)createOffscreenRenderCanvas:(uint32_t)surfaceId
{
    CGLayerRef buffer = [self.offscreenRenderSurfaces getSurfaceBufferForId:surfaceId];
    CGSize pixelSize = CGLayerGetSize(buffer);
    CGFloat scale = self.offscreenRenderSurfaces.scale;
    CGSize size = CGSizeMake(pixelSize.width / scale, pixelSize.height / scale);

    Canvas *canvas = [[Canvas alloc] init];
    canvas.context = CGLayerGetContext(buffer);
    canvas.offscreenRenderSurfaces = self.offscreenRenderSurfaces;
    CGContextSaveGState(canvas.context);
    canvas.size = size;
    return canvas;
}

- (void)releaseOffscreenRenderCanvas:(id<IINKICanvas>)canvas
{
    CGContextRestoreGState(((Canvas *)canvas).context);
}

#pragma mark - Constraints

- (void)updateViewConstraints
{
    [self initViewConstraints];
    [super updateViewConstraints];
}

- (void)initViewConstraints
{
    if (!self.didSetConstraints)
    {
        self.didSetConstraints = YES;
        
        NSDictionary *views = @{@"backgroundRenderView" : self.backgroundRenderView, @"modelRenderView" : self.modelRenderView, @"tempRenderView" : self.tempRenderView, @"captureRenderView" : self.captureRenderView};
        
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[backgroundRenderView]|" options:0 metrics:nil views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[backgroundRenderView]|" options:0 metrics:nil views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[modelRenderView]|" options:0 metrics:nil views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[modelRenderView]|" options:0 metrics:nil views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tempRenderView]|" options:0 metrics:nil views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tempRenderView]|" options:0 metrics:nil views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[captureRenderView]|" options:0 metrics:nil views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[captureRenderView]|" options:0 metrics:nil views:views]];
    }
}

@end
