This project has two targets, xboxshim executable and xboxcontroller.bundle

xboxshim is a lightweight executable that communicates with attached Xbox 360/One wired USB controllers.

The IOKit code is taken directly from the Chromium project's HTML5 game controller codebase, which is great because their code doesn't require HID drivers or .kexts to have been installed.

To facilitate integration with C#-based code, xboxshim communicates the controller state via UDP packets sent on the loopback interface.

To tickle a state update, send UTF8 'xbox state' to port 21337.

xboxshim will then dump the controller states (40 bytes x 4 controllers) onto port 21338.

Note that only one controller is supported at this time, but the code is 90%+ there to support up to 4 controllers.

'xbox reset' will shut down the shim and exit.

xboxcontroller.bundle removes the UDP connection and interops via the C functions:

    bool XboxControllerStart();
    void XboxControllerReset();
    bool XboxControllerState(uint8_t *buffer, int32_t buffer_size);

