//
//  ViewController.m
//  RS232 Tool
//
//  Created by zbh on 17/3/3.
//  Copyright © 2017年 zbh. All rights reserved.
//

#import "ViewController.h"
#import "ORSSerialPortManager.h"

@implementation ViewController


- (void)awakeFromNib{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        self.serialPortManager = [ORSSerialPortManager sharedSerialPortManager];
        self.availableBaudRates = @[@300, @1200, @2400, @4800, @9600, @14400, @19200, @28800, @38400, @57600, @115200, @230400];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(serialPortsWereConnected:) name:ORSSerialPortsWereConnectedNotification object:nil];
        [nc addObserver:self selector:@selector(serialPortsWereDisconnected:) name:ORSSerialPortsWereDisconnectedNotification object:nil];
        
#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_7)
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
#endif
    });
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)viewDidLoad {
    [super viewDidLoad];

    [self.RXDataDisplayTextView setEditable:NO];
    [self.RXCounter setEditable:NO];
    [self.TXCounter setEditable:NO];
    self.isRXHexString = YES;
    self.isTXHexString = YES;
    self.isRXGBKString = NO;
    self.isTXGBKString = NO;
    self.TXNumber = 0;
    self.RXNumber = 0;
    // Do any additional setup after loading the view.
    self.TXDataDisplayTextView.delegate = self;
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    // Update the view, if already loaded.
}

- (IBAction)openComPort:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.serialPort.isOpen ? [self.serialPort close] : [self.serialPort open];
    });
}

//设置接收区采用hexstring还是字符串显示方式
- (IBAction)setDisplayMode:(NSMatrix *)sender {
    if (sender.selectedTag==1) {
        self.isRXHexString = YES;
        [self.stringType setEnabled:NO];
    }else if(sender.selectedTag==2){
        self.isRXHexString = NO;
        [self.stringType setEnabled:YES];
    }
}

//设置发送区采用hexstring还是字符串发送
- (IBAction)setDisplayMode_TX:(NSMatrix *)sender {
    
    if (sender.selectedTag==1) {
        self.isTXHexString = YES;
        [self.stringType_TX setEnabled:NO];
    }else{
        self.isTXHexString = NO;
        [self.stringType_TX setEnabled:YES];
    }
}

//设置接收区字符串编码方式
- (IBAction)setStringDisplayEncode:(NSMatrix *)sender {
    [self.RXDataDisplayTextView setString:@""];
}

//设置发送区字符串编码方式
- (IBAction)setStringDisplayEncode_TX:(NSMatrix *)sender {
    if (sender.selectedTag==1) {
        _isTXGBKString = NO;
    }else{
        _isTXGBKString = YES;
    }
}


- (IBAction)sendData:(id)sender {
    
    self.StatusText.stringValue = @"发送数据中...";
    NSString *textStr = self.TXDataDisplayTextView.textStorage.mutableString;
    if(textStr.length==0){
        self.StatusText.stringValue = @"发送数据长度为0";
        return;
    }
    
    NSData *sendData;
    
    if (self.isTXHexString) {
        textStr = [textStr stringByReplacingOccurrencesOfString:@"," withString:@""];
        textStr = [textStr stringByReplacingOccurrencesOfString:@" " withString:@""];
        textStr = [textStr stringByReplacingOccurrencesOfString:@"0x" withString:@""];
        textStr = [textStr stringByReplacingOccurrencesOfString:@"\\x" withString:@""];
        if (textStr.length%2!=0) {
            self.StatusText.stringValue = @"发送16进制数据长度错误！";
            return;
        }
        
        NSString* number=@"^[a-f|A-F|0-9]+$";
        NSPredicate *numberPre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",number];
        if(![numberPre evaluateWithObject:textStr]){
            self.StatusText.stringValue = @"包含非[0-9A-Fa-f]字符！";
            return;
        }
        
        
        self.TXNumber += textStr.length/2;
        sendData = [ORSSerialPortManager twoOneData:textStr];
        [self.serialPort sendData:sendData];
        self.StatusText.stringValue = @"发送数据成功";
        self.TXCounter.stringValue = [NSString stringWithFormat:@"%ld",self.TXNumber];
        
    }else{
        
        const char* cstr;
        if (_isTXGBKString) {
            NSStringEncoding enc =CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
            cstr = [textStr cStringUsingEncoding:enc];
            self.StatusText.stringValue = @"发送GBK编码数据成功";
        }else{
            cstr = [textStr cStringUsingEncoding:NSUTF8StringEncoding];
            self.StatusText.stringValue = @"发送UTF8编码数据成功";
        }
        if(cstr!=NULL){
            self.TXNumber += strlen(cstr);
            sendData = [NSData dataWithBytes:cstr length:strlen(cstr)];
            [self.serialPort sendData:sendData];
            self.TXCounter.stringValue = [NSString stringWithFormat:@"%ld",self.TXNumber];
        }
    }
    
    //显示文字为深灰色，大小为14
    NSInteger startPorint = self.RXDataDisplayTextView.textStorage.length;
    NSString *sendStr = [NSString stringWithFormat:@"发送数据(HEX):%@\n",[ORSSerialPortManager oneTwoData:sendData]];
    NSInteger length = sendStr.length;
    [self.RXDataDisplayTextView.textStorage.mutableString appendString:sendStr];
    [self.RXDataDisplayTextView.textStorage addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:14] range:NSMakeRange(startPorint, length)];
    [self.RXDataDisplayTextView.textStorage addAttribute:NSForegroundColorAttributeName value:[NSColor darkGrayColor] range:NSMakeRange(startPorint, length)];
}

- (IBAction)clearTXDataDisplayTextView:(id)sender {
    self.StatusText.stringValue = @"已清空发送区";
    [self.TXDataDisplayTextView setString:@""];
}

- (IBAction)clearRXDataDisplayTextView:(id)sender {
    self.StatusText.stringValue = @"已清空接收区";
    [self.RXDataDisplayTextView setString:@""];
}

- (IBAction)clearCounter:(id)sender {
    
    self.RXNumber = 0;
    self.TXNumber = 0;
    self.TXCounter.stringValue=@"";
    self.RXCounter.stringValue = @"";
}


-(void)textDidChange:(NSNotification *)notification {
    
    [self.TXDataDisplayTextView.textStorage addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:18] range:NSMakeRange(0, [self.TXDataDisplayTextView string].length)];
    [self.TXDataDisplayTextView.textStorage addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(0, [self.TXDataDisplayTextView string].length)];
    [self.TXDataDisplayTextView.textStorage addAttribute:NSBackgroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(0, [self.TXDataDisplayTextView string].length)];
}

#pragma mark - ORSSerialPortDelegate Methods

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort
{
    self.OpenOrClose.title = @"关闭串口";
    self.StatusText.stringValue = @"串口已打开";
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort
{
    self.OpenOrClose.title = @"打开串口";
    self.StatusText.stringValue = @"串口已关闭";
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
    NSLog(@"收到数据: %@",data);
    self.StatusText.stringValue = @"收到一次数据...";
    self.RXNumber += data.length;
    self.RXCounter.stringValue = [NSString stringWithFormat:@"%ld",self.RXNumber];
    
    NSString *string;
    if (self.isRXHexString) {
        string = [ORSSerialPortManager oneTwoData:data];
    }else{
        
        if(self.isRXGBKString){
            NSStringEncoding enc =CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
            string = [NSString stringWithCString:(const char*)[data bytes] encoding:enc];
        }else{
            string = [NSString stringWithCString:(const char*)[data bytes] encoding:NSASCIIStringEncoding];
        }
    }
    if ([string length] == 0){
        return;
    }
    
    
    //显示文字为深灰色，大小为14
    NSInteger startPorint = self.RXDataDisplayTextView.textStorage.length;
    NSInteger length = string.length;
    [self.RXDataDisplayTextView.textStorage.mutableString appendString:string];
    [self.RXDataDisplayTextView.textStorage addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:14] range:NSMakeRange(startPorint, length)];
    
    static int i = 0;
    if(i%2==0){
        [self.RXDataDisplayTextView.textStorage addAttribute:NSForegroundColorAttributeName value:[NSColor greenColor] range:NSMakeRange(startPorint, length)];
        [self.RXDataDisplayTextView.textStorage addAttribute:NSBackgroundColorAttributeName value:[NSColor brownColor] range:NSMakeRange(startPorint, length)];
    }else{
        [self.RXDataDisplayTextView.textStorage addAttribute:NSForegroundColorAttributeName value:[NSColor yellowColor] range:NSMakeRange(startPorint, length)];
        [self.RXDataDisplayTextView.textStorage addAttribute:NSBackgroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(startPorint, length)];
    }
    i++;
    
    [self.RXDataDisplayTextView setNeedsDisplay:YES];
    self.StatusText.stringValue = @"数据接收完毕";
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort;
{
    // After a serial port is removed from the system, it is invalid and we must discard any references to it
    self.serialPort = nil;
    self.OpenOrClose.title = @"打开串口";
}

- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error
{
    NSLog(@"Serial port %@ encountered an error: %@", serialPort, error);
    self.StatusText.stringValue = [NSString stringWithFormat:@"错误:%@",error.userInfo[@"NSLocalizedDescription"]];
}

#pragma mark - NSUserNotificationCenterDelegate

#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_7)

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification
{
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [center removeDeliveredNotification:notification];
    });
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

#endif

#pragma mark - Notifications

- (void)serialPortsWereConnected:(NSNotification *)notification
{
    NSArray *connectedPorts = [notification userInfo][ORSConnectedSerialPortsKey];
    NSLog(@"Ports were connected: %@", connectedPorts);
    [self postUserNotificationForConnectedPorts:connectedPorts];
}

- (void)serialPortsWereDisconnected:(NSNotification *)notification
{
    NSArray *disconnectedPorts = [notification userInfo][ORSDisconnectedSerialPortsKey];
    NSLog(@"Ports were disconnected: %@", disconnectedPorts);
    [self postUserNotificationForDisconnectedPorts:disconnectedPorts];
    
}

- (void)postUserNotificationForConnectedPorts:(NSArray *)connectedPorts
{
#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_7)
    if (!NSClassFromString(@"NSUserNotificationCenter")) return;
    
    NSUserNotificationCenter *unc = [NSUserNotificationCenter defaultUserNotificationCenter];
    for (ORSSerialPort *port in connectedPorts)
    {
        NSUserNotification *userNote = [[NSUserNotification alloc] init];
        userNote.title = NSLocalizedString(@"Serial Port Connected", @"Serial Port Connected");
        NSString *informativeTextFormat = NSLocalizedString(@"Serial Port %@ was connected to your Mac.", @"Serial port connected user notification informative text");
        userNote.informativeText = [NSString stringWithFormat:informativeTextFormat, port.name];
        userNote.soundName = nil;
        [unc deliverNotification:userNote];
    }
#endif
}

- (void)postUserNotificationForDisconnectedPorts:(NSArray *)disconnectedPorts
{
#if (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_7)
    if (!NSClassFromString(@"NSUserNotificationCenter")) return;
    
    NSUserNotificationCenter *unc = [NSUserNotificationCenter defaultUserNotificationCenter];
    for (ORSSerialPort *port in disconnectedPorts)
    {
        NSUserNotification *userNote = [[NSUserNotification alloc] init];
        userNote.title = NSLocalizedString(@"Serial Port Disconnected", @"Serial Port Disconnected");
        NSString *informativeTextFormat = NSLocalizedString(@"Serial Port %@ was disconnected from your Mac.", @"Serial port disconnected user notification informative text");
        userNote.informativeText = [NSString stringWithFormat:informativeTextFormat, port.name];
        userNote.soundName = nil;
        [unc deliverNotification:userNote];
    }
#endif
}


#pragma mark - Properties

- (void)setSerialPort:(ORSSerialPort *)port
{
    if (port != _serialPort)
    {
        [_serialPort close];
        _serialPort.delegate = nil;
        
        _serialPort = port;
        
        _serialPort.delegate = self;
    }
}

@end
