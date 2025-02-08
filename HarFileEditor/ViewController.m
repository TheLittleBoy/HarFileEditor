//
//  ViewController.m
//  HarFileEditor
//
//  Created by iMac on 2025/2/7.
//

#import "ViewController.h"

@interface ViewController ()

@property (nonatomic, strong) NSString *tempExtractPath; // 新增
@property (unsafe_unretained) IBOutlet NSTextView *textView;
@property (nonatomic, strong) NSString *filePath;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    
    //禁用自动更正功能
    [self.textView setAutomaticSpellingCorrectionEnabled:NO];
    [self.textView setAutomaticTextReplacementEnabled:NO];
    [self.textView setAutomaticDataDetectionEnabled:NO];
    [self.textView setAutomaticLinkDetectionEnabled:NO];
    [self.textView setAutomaticTextCompletionEnabled:NO];
    [self.textView setAutomaticDashSubstitutionEnabled:NO];
    [self.textView setAutomaticQuoteSubstitutionEnabled:NO];
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)openButtonAction:(id)sender {
    
    // 显示打开面板
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowedFileTypes:@[@"har"]];  // 只允许选择 .har 文件
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setPrompt:@"选择一个压缩文件"];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        NSArray *files = [openPanel URLs];
        if ([files count] > 0) {
            NSURL *fileURL = [files objectAtIndex:0];
            [self processFileAtPath:fileURL.relativePath];
        }
    }
    
}


- (void)processFileAtPath:(NSString *)path {
    self.filePath = path;
    // 解压缩文件并查找oh-package.json5
    [self extractAndParseJSON];
}

- (void)extractAndParseJSON {
    // 创建临时解压目录（确保唯一性）
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    
    // 使用 NSTask 调用 tar 命令解压
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/tar"];
    [task setArguments:@[@"-xvf", self.filePath, @"-C", tempDir]]; // -C 指定解压目录
    
    // 捕获错误输出
    NSPipe *errorPipe = [NSPipe pipe];
    [task setStandardError:errorPipe];
    
    [task launch];
    [task waitUntilExit];
    
    // 检查解压是否成功
    if ([task terminationStatus] != 0) {
        NSData *errorData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
        NSString *errorMessage = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
        NSLog(@"解压失败: %@", errorMessage);
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"发生错误";
        alert.informativeText = [NSString stringWithFormat:@"解压失败：%@", errorMessage];
        [alert addButtonWithTitle:@"确定"];
        [alert runModal];
        return;
    }
    
    // 检查 oh-package.json5 是否存在
    NSString *jsonFilePath = [tempDir stringByAppendingPathComponent:@"package/oh-package.json5"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:jsonFilePath]) {
        NSLog(@"oh-package.json5 不存在");
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"发生错误";
        alert.informativeText = @"oh-package.json5 文件不存在";
        [alert addButtonWithTitle:@"确定"];
        [alert runModal];
        return;
    }
    
    // 解析 JSON 文件
    NSData *jsonData = [NSData dataWithContentsOfFile:jsonFilePath];
    NSError *error;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
    
    if (!error) {
        NSLog(@"解压成功！");
        [self displayJSON:jsonDict];
        self.tempExtractPath = tempDir; // 保存临时目录供后续使用
    } else {
        NSLog(@"JSON 解析错误: %@", error.localizedDescription);
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"文件格式错误";
        alert.informativeText = [NSString stringWithFormat:@"错误信息：%@", error.localizedDescription];
        [alert addButtonWithTitle:@"确定"];
        [alert runModal];
        return;
    }
}

- (void)displayJSON:(NSDictionary *)jsonDict {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    self.textView.string = jsonString;
}


- (IBAction)saveButtonAction:(id)sender {
    NSString *jsonString = self.textView.string;
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
    if (!error) {
        [self saveJSON:jsonDict];
    } else {
        NSLog(@"Error parsing JSON: %@", error.localizedDescription);
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"内容格式错误";
        alert.informativeText = [NSString stringWithFormat:@"错误信息：%@", error.localizedDescription];
        [alert addButtonWithTitle:@"确定"];
        [alert runModal];
        return;
    }
}


- (void)saveJSON:(NSDictionary *)jsonDict {
    // 1. 保存修改后的 JSON 到临时目录
    NSString *jsonFilePath = [self.tempExtractPath stringByAppendingPathComponent:@"package/oh-package.json5"];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil];
    [jsonData writeToFile:jsonFilePath atomically:YES];
    
    // 2. 调用 tar 命令重新压缩
    NSTask *compressTask = [[NSTask alloc] init];
    [compressTask setLaunchPath:@"/usr/bin/tar"];
    
    // 生成临时压缩文件名
    NSString *tempZipPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"modified_temp.har"];
    
    // 参数说明：-c 创建压缩包，-v 显示详情，-z 使用gzip，-f 指定文件名
    // 注意：需要先进入临时目录，否则压缩包会包含完整路径
    [compressTask setArguments:@[
        @"-cvzf", tempZipPath,
        @"-C", self.tempExtractPath, // 指定工作目录
        @"package"                         // 压缩当前目录所有内容
    ]];
    
    // 捕获错误
    NSPipe *compressErrorPipe = [NSPipe pipe];
    [compressTask setStandardError:compressErrorPipe];
    
    [compressTask launch];
    [compressTask waitUntilExit];
    
    if ([compressTask terminationStatus] != 0) {
        NSData *errorData = [[compressErrorPipe fileHandleForReading] readDataToEndOfFile];
        NSString *errorMessage = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
        NSLog(@"压缩失败: %@", errorMessage);
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"发生错误";
        alert.informativeText = [NSString stringWithFormat:@"压缩失败：%@", errorMessage];
        [alert addButtonWithTitle:@"确定"];
        [alert runModal];
        return;
    }
    
    // 3. 弹出保存对话框
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setNameFieldStringValue:self.filePath.lastPathComponent];
    if ([savePanel runModal] == NSModalResponseOK) {
        NSURL *saveURL = [savePanel URL];
        [[NSFileManager defaultManager] copyItemAtPath:tempZipPath
                                                toPath:[saveURL path]
                                                 error:nil];
        
        
        // 4. 清理临时文件（可选）
        [[NSFileManager defaultManager] removeItemAtPath:self.tempExtractPath error:nil];
        
        self.textView.string = @"保存成功！";
        
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:tempZipPath error:nil];

}

@end

