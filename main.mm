#import <Foundation/Foundation.h>

#import "xbox_data_fetcher_mac.h"
#import "GCDAsyncUdpSocket.h"

@interface DeviceManager : NSObject <XboxDeviceEventDelegate>
@property BOOL active;
@end

@implementation DeviceManager
{
    XboxDataFetcher *fetcher;
    GCDAsyncUdpSocket* socket;
    XboxController *controller_devices[4];
    XboxController::Data controller_states[4];
}

- (instancetype) init
{
    fetcher = new XboxDataFetcher(self);

    bool ok = fetcher->RegisterForNotifications();
    
    NSLog(@"Register for Xbox notifications: %s", ok ? "OK" : "FAIL");
    
    if (!ok)
        return self;
    
    socket = [[GCDAsyncUdpSocket alloc] initWithDelegate: self delegateQueue: dispatch_get_main_queue()];
    
    uint16_t port_num = 21337;
    
    if (![socket bindToPort: port_num error: nil])
        NSLog(@"Error: Could not bind to port %d", port_num);
    else if (![socket beginReceiving: nil])
        NSLog(@"Error: Could not begin receiving on port %d", port_num);
    else
        self.active = YES;
    
    return self;
}

- (void) dealloc
{
    NSLog(@"DeviceManager dealloc");
}

- (void) udpSocket: (GCDAsyncUdpSocket*) sock didReceiveData: (NSData*) data fromAddress: (NSData*) address withFilterContext: (id) filterContext
{
    NSString *msg = [[NSString alloc] initWithData:data encoding: NSUTF8StringEncoding];

    if ([msg isEqualToString: @"xbox reset"])
        [self resetCommand];
    
    if ([msg isEqualToString: @"xbox state"])
        [self stateCommand];
}
    
- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error
{
    NSLog(@"Socket closed for some reason :(");

    self.active = NO;
}

- (void) XboxDeviceAdd: (XboxController*) device
{
    //TODO: support more than one controller!

    controller_devices[0] = device;
    controller_states[0].connected = true;

    NSLog(@"Device Added: %p", device);

    device->SetLEDPattern(XboxController::LED_FLASH_TOP_LEFT);
}

- (void) XboxDeviceRemove: (XboxController*) device
{
    //TODO: support more than one controller!

    controller_devices[0] = NULL;
    controller_states[0].connected = false;

    NSLog(@"Device Removed: %p", device);
}

- (void) XboxValueChanged: (XboxController*) device data: (const XboxController::Data&) data
{
    //TODO: support more than one controller!
    
    controller_states[0] = data;
    controller_states[0].connected = true;
 }

- (void) resetCommand
{
    // turn off all controllers' LEDs:
    
    for (int i = 0; i < 4; i++)
        if (controller_devices[i] != NULL)
            controller_devices[i]->SetLEDPattern(XboxController::LED_FLASH_ONCE);
    
    if (fetcher != NULL)
        fetcher->UnregisterFromNotifications();

    // tell main() to quit:
    
    self.active = NO;
}

- (void) stateCommand
{
    [socket sendData: [NSData dataWithBytes: controller_states length: sizeof(controller_states)] toHost: @"loopback" port: 21338 withTimeout: 0.0 tag: 0];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {

        DeviceManager *devices = [DeviceManager new];

        while (devices.active && [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate: NSDate.distantFuture])
            continue;
        
        NSLog(@"Terminating . . .");

        sleep(1); // give time for fetcher to teardown
    }
    
    return 0;
}
