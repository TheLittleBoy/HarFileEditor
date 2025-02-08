//
//  WindowController.m
//  HarFileEditor
//
//  Created by iMac on 2025/2/8.
//

#import "WindowController.h"

@interface WindowController ()<NSWindowDelegate>

@end

@implementation WindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    self.window.delegate = self;
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    // 这里你可以添加一些逻辑来判断是否真的要关闭应用程序
    // 比如检查是否有未保存的更改等
      
    // 如果确定要关闭应用程序，就调用 NSApplication 的 terminate 方法
    [NSApp terminate:self];
      
    // 返回 NO 表示我们已经处理了关闭操作，不需要系统再处理
    return NO;
}

@end
