Source code for PIC16F88.
This firmware realize to merge two MIDI input channels into one MIDI output.
Also apply some filtering for channel 16. Program changes for channel 16 are masked and all note events for channel 16 are rewritten as events for another channel which is specified as program number.