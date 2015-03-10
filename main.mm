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
    
#ifdef BUNDLE_TARGET
    self.active = YES;
#else
    socket = [[GCDAsyncUdpSocket alloc] initWithDelegate: self delegateQueue: dispatch_get_main_queue()];
    
    uint16_t port_num = 21337;
    
    if (![socket bindToPort: port_num error: nil])
        NSLog(@"Error: Could not bind to port %d", port_num);
    else if (![socket beginReceiving: nil])
        NSLog(@"Error: Could not begin receiving on port %d", port_num);
    else
        self.active = YES;
#endif

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
    NSLog(@"Xbox reset begin");

    // turn off all controllers' LEDs:
    
    for (int i = 0; i < 4; i++)
        if (controller_devices[i] != NULL)
            controller_devices[i]->SetLEDPattern(XboxController::LED_FLASH_ONCE);
    
    if (fetcher != NULL);
    {
        delete fetcher; fetcher = NULL;
    }
    
    // tell main() to quit:
    
    self.active = NO;

    NSLog(@"Xbox reset end");
}

- (void) stateCommand
{
    [socket sendData: [NSData dataWithBytes: controller_states length: sizeof(controller_states)] toHost: @"loopback" port: 21338 withTimeout: 0.0 tag: 0];
}

- (bool) getState: (uint8_t*) buffer size: (uint32_t) buffer_size
{
    if (buffer_size != sizeof(controller_states))
        return false;
    
    memcpy(buffer, controller_states, sizeof(controller_states));
    
    return true;
}

@end

#ifdef BUNDLE_TARGET

extern "C"
{
    bool XboxControllerStart();
    void XboxControllerReset();
    bool XboxControllerState(uint8_t *buffer, int32_t buffer_size);
}

DeviceManager *devices;

bool XboxControllerStart()
{
    devices = [DeviceManager new];
    
    return devices.active;
}

void XboxControllerReset()
{
    if (!devices)
        return;
    
    [devices resetCommand];
    
    devices = nil;
}

bool XboxControllerState(uint8_t *buffer, int32_t buffer_size)
{
    if (!devices || !devices.active)
        return false;
    
    return [devices getState: buffer size: buffer_size];
}

#else

int main(int argc, const char * argv[]) {
    @autoreleasepool {

        DeviceManager *devices = [DeviceManager new];

        while (devices.active && [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate: NSDate.distantFuture])
            continue;
    }
    
    return 0;
}
#endif
