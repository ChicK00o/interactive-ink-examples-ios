// Copyright MyScript. All right reserved.

#import <Foundation/Foundation.h>
#import <iink/IINKEditor.h>

@interface ImageLoader : NSObject

@property (weak, nonatomic) IINKEditor *editor;

- (id)imageFromURL:(NSString *)key;

@end
