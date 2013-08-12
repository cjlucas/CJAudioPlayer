CJAudioPlayer
-------------
An audio player for iOS and OS X built on top of [the Audjustable audio player](https://github.com/tumtumtum/audjustable). It implements all of the mundane queue management logic so you don't have to. 

Usage
-----
- Initialize a `CJAudioPlayer` object
- Add items (see: `<CJAudioPlayerQueueItem>`)
- Call `- (void)play`

Features
--------
- All of the great, low level features of Audjustable such as prebuffering and gapless playback
- Audio queue management
- Support for shuffle and continuous playback modes
- Automatic disk caching
- Intellegent prebuffering
- Handles audio session interruptions automatically
- A full-featured example project
	
Requirements
------------
- [Audjustable](https://github.com/tumtumtum/audjustable) 0.0.6+
- iOS 7.0+
- OS X 10.8+

Contributing
------------
Contributions are welcome and greatly appreciated. Just make sure you're working on the `develop` branch.

TODO
----
- Documentation
- Support for chunked HTTP requests
- Support file seeking
