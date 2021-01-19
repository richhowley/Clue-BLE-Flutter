# Clue BLE Flutter/Dart App

This is a starter Flutter/Dart app to get an Adafruit Clue and a mobile device performing bidirectional communication via BLE. 

It uses the [flutter_blue](https://pub.dev/packages/flutter_blue) plugin. I have an Android device so did not set up permissions for iOS, there are directions on how do do that on the pub.dev page.

The [UART Serivce](https://learn.adafruit.com/introducing-adafruit-ble-bluetooth-low-energy-friend/uart-service), documented by Adafruit, is used to pass strings between devices. The app main screen has three buttons: Connect, Disconnect and Send Text. When the devices are connected the Send Text button will send the string "Goodnight Moon" to the Clue. A CircuitPython program running on the Clue echos the message to the device with the count of how many messages it has received since the last connection.

When I plugged in my Clue it advertised as CIRCUITPYbc57. Not sure if they are all the same but the advertising name is at the top of main.dart. Load the following CircuitPython program on the Clue and you should be able to communicate with this app.

```
from adafruit_ble import BLERadio
from adafruit_ble.advertising.standard import ProvideServicesAdvertisement
from adafruit_ble.services.nordic import UARTService
from adafruit_clue import clue

# turn on BLE
ble = BLERadio()
uart = UARTService()


while True:
    
    # start advertising
    advertisement = ProvideServicesAdvertisement(uart)
    ble.start_advertising(advertisement)
    print("Clue starting advertisement ...");
    
    # wait to be connected
    while not ble.connected:
        pass
    
    print("Clue connected.");
    
    msg_count = 0; # messages recieved

    while ble.connected:
        
        # get # of bytes in buffer
        in_cnt = uart.in_waiting
        
        # if UART has bytes waiting
        if in_cnt:
        
            # read message serial port
            rxbuf = uart.read(in_cnt)
        
            #  print it
            print(rxbuf)
            
            # increment count
            msg_count += 1
            
            # send massage and count to central
            uart.write("{msg} ({count})".format(msg=rxbuf.decode(),count = msg_count))
          
    print("Clue disconnected")
    
    ```
