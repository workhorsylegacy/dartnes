/*
JSNES, based on Jamie Sanders' vNES
Copyright (C) 2010 Ben Firshman

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import 'nes.dart';

class JSNES_PAPU {
  JSNES_NES nes = null;
  
  JSNES_PAPU_ChannelSquare square1 = null;
  JSNES_PAPU_ChannelSquare square2 = null;
  JSNES_PAPU_ChannelTriangle triangle = null;
  JSNES_PAPU_ChannelNoise noise = null;
  JSNES_PAPU_ChannelDM dmc = null;
  
  int frameIrqCounter;
  int frameIrqCounterMax;
  int initCounter;
  int channelEnableValue;

  int bufferSize;
  int bufferIndex;
  int sampleRate;

  List<int> lengthLookup = null;
  List<int> dmcFreqLookup = null;
  List<int> noiseWavelengthLookup = null;
  List<int> square_table = null;
  List<int> tnd_table = null;
  List<int> sampleBuffer = null;

  bool frameIrqEnabled;
  bool frameIrqActive;
  //frameClockNow = null;
  bool startedPlaying=false;
  bool recordOutput = false;
  bool initingHardware = false;

  int masterFrameCounter;
  int derivedFrameCounter;
  int countSequence;
  int sampleTimer;
  int frameTime;
  int sampleTimerMax;
  int sampleCount;
  int triValue;

  int smpSquare1;
  int smpSquare2;
  int smpTriangle;
  int smpDmc;
  int accCount;

  // DC removal vars:
  int prevSampleL = 0;
  int prevSampleR = 0;
  int smpAccumL = 0;
  int smpAccumR = 0;

  // DAC range:
  int dacRange = 0;
  int dcValue = 0;

  // Master volume:
  int masterVolume = 256;

  // Stereo positioning:
  int stereoPosLSquare1;
  int stereoPosLSquare2;
  int stereoPosLTriangle;
  int stereoPosLNoise;
  int stereoPosLDMC;
  int stereoPosRSquare1;
  int stereoPosRSquare2;
  int stereoPosRTriangle;
  int stereoPosRNoise;
  int stereoPosRDMC;

  int extraCycles;
  
  int maxSample;
  int minSample;
  
  List<int> panning = null;
  
  JSNES_PAPU(JSNES_NES nes) {
    this.nes = nes;
    
    this.square1 = new JSNES_PAPU_ChannelSquare(this, true);
    this.square2 = new JSNES_PAPU_ChannelSquare(this, false);
    this.triangle = new JSNES_PAPU_ChannelTriangle(this);
    this.noise = new JSNES_PAPU_ChannelNoise(this);
    this.dmc = new JSNES_PAPU_ChannelDM(this);

    this.frameIrqCounter = null;
    this.frameIrqCounterMax = 4;
    this.initCounter = 2048;
    this.channelEnableValue = null;

    this.bufferSize = 8192;
    this.bufferIndex = 0;
    this.sampleRate = 44100;

    this.lengthLookup = null;
    this.dmcFreqLookup = null;
    this.noiseWavelengthLookup = null;
    this.square_table = null;
    this.tnd_table = null;
    this.sampleBuffer = new List<int>(this.bufferSize*2);

    this.frameIrqEnabled = false;
    this.frameIrqActive = null;
    //this.frameClockNow = null;
    this.startedPlaying=false;
    this.recordOutput = false;
    this.initingHardware = false;

    this.masterFrameCounter = 0;
    this.derivedFrameCounter = 0;
    this.countSequence = 0;
    this.sampleTimer = 0;
    this.frameTime = 0;
    this.sampleTimerMax = 0;
    this.sampleCount = 0;
    this.triValue = 0;

    this.smpSquare1 = 0;
    this.smpSquare2 = 0;
    this.smpTriangle = 0;
    this.smpDmc = 0;
    this.accCount = 0;

    // DC removal vars:
    this.prevSampleL = 0;
    this.prevSampleR = 0;
    this.smpAccumL = 0;
    this.smpAccumR = 0;

    // DAC range:
    this.dacRange = 0;
    this.dcValue = 0;

    // Master volume:
    this.masterVolume = 256;

    // Stereo positioning:
    this.stereoPosLSquare1 = 0;
    this.stereoPosLSquare2 = 0;
    this.stereoPosLTriangle = 0;
    this.stereoPosLNoise = 0;
    this.stereoPosLDMC = 0;
    this.stereoPosRSquare1 = 0;
    this.stereoPosRSquare2 = 0;
    this.stereoPosRTriangle = 0;
    this.stereoPosRNoise = 0;
    this.stereoPosRDMC = 0;

    this.extraCycles = 0;
    
    this.maxSample = 0;
    this.minSample = 0;
    
    // Panning:
    this.panning = [80, 170, 100, 150, 128];
    this.setPanning(this.panning);

    // Initialize lookup tables:
    this.initLengthLookup();
    this.initDmcFrequencyLookup();
    this.initNoiseWavelengthLookup();
    this.initDACtables();
    
    // Init sound registers:
    for (int i = 0; i < 0x14; i++) {
        if (i == 0x10){
            this.writeReg(0x4010, 0x10);
        }
        else {
            this.writeReg(0x4000 + i, 0);
        }
    }
    
    this.reset();
  }
    void reset() {
        this.sampleRate = this.nes.opts['sampleRate'];
        this.sampleTimerMax = (
            (1024.0 * this.nes.opts['CPU_FREQ_NTSC'] *
                this.nes.opts['preferredFrameRate']) / 
                (this.sampleRate * 60.0)
        ).floor();
    
        this.frameTime = (
            (14915.0 * this.nes.opts['preferredFrameRate']) / 60.0
        ).floor();

        this.sampleTimer = 0;
        this.bufferIndex = 0;
    
        this.updateChannelEnable(0);
        this.masterFrameCounter = 0;
        this.derivedFrameCounter = 0;
        this.countSequence = 0;
        this.sampleCount = 0;
        this.initCounter = 2048;
        this.frameIrqEnabled = false;
        this.initingHardware = false;

        this.resetCounter();

        this.square1.reset();
        this.square2.reset();
        this.triangle.reset();
        this.noise.reset();
        this.dmc.reset();

        this.bufferIndex = 0;
        this.accCount = 0;
        this.smpSquare1 = 0;
        this.smpSquare2 = 0;
        this.smpTriangle = 0;
        this.smpDmc = 0;

        this.frameIrqEnabled = false;
        this.frameIrqCounterMax = 4;

        this.channelEnableValue = 0xFF;
        this.startedPlaying = false;
        this.prevSampleL = 0;
        this.prevSampleR = 0;
        this.smpAccumL = 0;
        this.smpAccumR = 0;
    
        this.maxSample = -500000;
        this.minSample = 500000;
    }

    int readReg(int address){
        // Read 0x4015:
        int tmp = 0;
        tmp |= (this.square1.getLengthStatus()   );
        tmp |= (this.square2.getLengthStatus() <<1);
        tmp |= (this.triangle.getLengthStatus()<<2);
        tmp |= (this.noise.getLengthStatus()   <<3);
        tmp |= (this.dmc.getLengthStatus()     <<4);
        tmp |= (((this.frameIrqActive && this.frameIrqEnabled)? 1 : 0) << 6);
        tmp |= (this.dmc.getIrqStatus()        <<7);

        this.frameIrqActive = false;
        this.dmc.irqGenerated = false;
    
        return tmp & 0xFFFF;
    }

    void writeReg(int address, int value){
        if (address >= 0x4000 && address < 0x4004) {
            // Square Wave 1 Control
            this.square1.writeReg(address, value);
            ////System.out.println("Square Write");
        }
        else if (address >= 0x4004 && address < 0x4008) {
            // Square 2 Control
            this.square2.writeReg(address, value);
        }
        else if (address >= 0x4008 && address < 0x400C) {
            // Triangle Control
            this.triangle.writeReg(address, value);
        }
        else if (address >= 0x400C && address <= 0x400F) {
            // Noise Control
            this.noise.writeReg(address, value);
        }
        else if (address == 0x4010){
            // DMC Play mode & DMA frequency
            this.dmc.writeReg(address, value);
        }
        else if (address == 0x4011){
            // DMC Delta Counter
            this.dmc.writeReg(address, value);
        }
        else if (address == 0x4012){
            // DMC Play code starting address
            this.dmc.writeReg(address, value);
        }
        else if (address == 0x4013){
            // DMC Play code length
            this.dmc.writeReg(address, value);
        }
        else if (address == 0x4015){
            // Channel enable
            this.updateChannelEnable(value);

            if (value != 0 && this.initCounter > 0) {
                // Start hardware initialization
                this.initingHardware = true;
            }

            // DMC/IRQ Status
            this.dmc.writeReg(address, value);
        }
        else if (address == 0x4017) {
            // Frame counter control
            this.countSequence = (value>>7)&1;
            this.masterFrameCounter = 0;
            this.frameIrqActive = false;

            if (((value>>6)&0x1)==0){
                this.frameIrqEnabled = true;
            }
            else {
                this.frameIrqEnabled = false;
            }

            if (this.countSequence == 0) {
                // NTSC:
                this.frameIrqCounterMax = 4;
                this.derivedFrameCounter = 4;
            }
            else {
                // PAL:
                this.frameIrqCounterMax = 5;
                this.derivedFrameCounter = 0;
                this.frameCounterTick();
            }
        }
    }

    void resetCounter() {
        if (this.countSequence == 0) {
            this.derivedFrameCounter = 4;
        }else{
            this.derivedFrameCounter = 0;
        }
    }

    // Updates channel enable status.
    // This is done on writes to the
    // channel enable register (0x4015),
    // and when the user enables/disables channels
    // in the GUI.
    void updateChannelEnable(int value){
        this.channelEnableValue = value&0xFFFF;
        this.square1.setEnabled((value&1) != 0);
        this.square2.setEnabled((value&2) != 0);
        this.triangle.setEnabled((value&4) != 0);
        this.noise.setEnabled((value&8) != 0);
        this.dmc.setEnabled((value&16) != 0);
    }

    // Clocks the frame counter. It should be clocked at
    // twice the cpu speed, so the cycles will be
    // divided by 2 for those counters that are
    // clocked at cpu speed.
    void clockFrameCounter(int nCycles){
        if (this.initCounter > 0) {
            if (this.initingHardware) {
                this.initCounter -= nCycles;
                if (this.initCounter <= 0) {
                    this.initingHardware = false;
                }
                return;
            }
        }

        // Don't process ticks beyond next sampling:
        nCycles += this.extraCycles;
        int maxCycles = this.sampleTimerMax-this.sampleTimer;
        if ((nCycles<<10) > maxCycles) {

            this.extraCycles = ((nCycles<<10) - maxCycles)>>10;
            nCycles -= this.extraCycles;

        }else{
        
            this.extraCycles = 0;
        
        }
    
        JSNES_PAPU_ChannelDM dmc = this.dmc;
        JSNES_PAPU_ChannelTriangle triangle = this.triangle;
        JSNES_PAPU_ChannelSquare square1 = this.square1;
        JSNES_PAPU_ChannelSquare square2 = this.square2;
        JSNES_PAPU_ChannelNoise noise = this.noise;
    
        // Clock DMC:
        if (dmc.isEnabled) {
        
            dmc.shiftCounter-=(nCycles<<3);
            while(dmc.shiftCounter<=0 && dmc.dmaFrequency>0){
                dmc.shiftCounter += dmc.dmaFrequency;
                dmc.clockDmc();
            }

        }

        // Clock Triangle channel Prog timer:
        if (triangle.progTimerMax>0) {
        
            triangle.progTimerCount -= nCycles;
            while(triangle.progTimerCount <= 0){
            
                triangle.progTimerCount += triangle.progTimerMax+1;
                if (triangle.linearCounter>0 && triangle.lengthCounter>0) {

                    triangle.triangleCounter++;
                    triangle.triangleCounter &= 0x1F;

                    if (triangle.isEnabled) {
                        if (triangle.triangleCounter>=0x10) {
                            // Normal value.
                            triangle.sampleValue = (triangle.triangleCounter&0xF);
                        }else{
                            // Inverted value.
                            triangle.sampleValue = (0xF - (triangle.triangleCounter&0xF));
                        }
                        triangle.sampleValue <<= 4;
                    }
                }
            }
        }

        // Clock Square channel 1 Prog timer:
        square1.progTimerCount -= nCycles;
        if (square1.progTimerCount <= 0) {

            square1.progTimerCount += (square1.progTimerMax+1)<<1;

            square1.squareCounter++;
            square1.squareCounter&=0x7;
            square1.updateSampleValue();
            
        }

        // Clock Square channel 2 Prog timer:
        square2.progTimerCount -= nCycles;
        if (square2.progTimerCount <= 0) {

            square2.progTimerCount += (square2.progTimerMax+1)<<1;

            square2.squareCounter++;
            square2.squareCounter&=0x7;
            square2.updateSampleValue();
        
        }

        // Clock noise channel Prog timer:
        int acc_c = nCycles;
        if (noise.progTimerCount-acc_c > 0) {
        
            // Do all cycles at once:
            noise.progTimerCount -= acc_c;
            noise.accCount       += acc_c;
            noise.accValue       += acc_c * noise.sampleValue;
        
        }else{
        
            // Slow-step:
            while((acc_c--) > 0){
            
                if (--noise.progTimerCount <= 0 && noise.progTimerMax>0) {
    
                    // Update noise shift register:
                    noise.shiftReg <<= 1;
                    noise.tmp = (((noise.shiftReg << (noise.randomMode==0?1:6)) ^ noise.shiftReg) & 0x8000 );
                    if (noise.tmp != 0) {
                    
                        // Sample value must be 0.
                        noise.shiftReg |= 0x01;
                        noise.randomBit = 0;
                        noise.sampleValue = 0;
                    
                    }else{
                    
                        // Find sample value:
                        noise.randomBit = 1;
                        if (noise.isEnabled && noise.lengthCounter>0) {
                            noise.sampleValue = noise.masterVolume;
                        }else{
                            noise.sampleValue = 0;
                        }
                    
                    }
                
                    noise.progTimerCount += noise.progTimerMax;
                    
                }
        
                noise.accValue += noise.sampleValue;
                noise.accCount++;
        
            }
        }
    

        // Frame IRQ handling:
        if (this.frameIrqEnabled && this.frameIrqActive){
            this.nes.cpu.requestIrq(this.nes.cpu.IRQ_NORMAL);
        }

        // Clock frame counter at double CPU speed:
        this.masterFrameCounter += (nCycles<<1);
        if (this.masterFrameCounter >= this.frameTime) {
            // 240Hz tick:
            this.masterFrameCounter -= this.frameTime;
            this.frameCounterTick();
        }
    
        // Accumulate sample value:
        this.accSample(nCycles);

        // Clock sample timer:
        this.sampleTimer += nCycles<<10;
        if (this.sampleTimer>=this.sampleTimerMax) {
            // Sample channels:
            this.sample();
            this.sampleTimer -= this.sampleTimerMax;
        }
    }

    void accSample(int cycles) {
        // Special treatment for triangle channel - need to interpolate.
        if (this.triangle.sampleCondition) {
            this.triValue = ((this.triangle.progTimerCount << 4) /
                    (this.triangle.progTimerMax + 1)).floor();
            if (this.triValue > 16) {
                this.triValue = 16;
            }
            if (this.triangle.triangleCounter >= 16) {
                this.triValue = 16 - this.triValue;
            }
        
            // Add non-interpolated sample value:
            this.triValue += this.triangle.sampleValue;
        }
    
        // Now sample normally:
        if (cycles == 2) {
        
            this.smpTriangle += this.triValue                << 1;
            this.smpDmc      += this.dmc.sample         << 1;
            this.smpSquare1  += this.square1.sampleValue    << 1;
            this.smpSquare2  += this.square2.sampleValue    << 1;
            this.accCount    += 2;
        
        }else if (cycles == 4) {
        
            this.smpTriangle += this.triValue                << 2;
            this.smpDmc      += this.dmc.sample         << 2;
            this.smpSquare1  += this.square1.sampleValue    << 2;
            this.smpSquare2  += this.square2.sampleValue    << 2;
            this.accCount    += 4;
        
        }else{
        
            this.smpTriangle += cycles * this.triValue;
            this.smpDmc      += cycles * this.dmc.sample;
            this.smpSquare1  += cycles * this.square1.sampleValue;
            this.smpSquare2  += cycles * this.square2.sampleValue;
            this.accCount    += cycles;
        
        }
    
    }

    void frameCounterTick(){
    
        this.derivedFrameCounter++;
        if (this.derivedFrameCounter >= this.frameIrqCounterMax) {
            this.derivedFrameCounter = 0;
        }
    
        if (this.derivedFrameCounter==1 || this.derivedFrameCounter==3) {

            // Clock length & sweep:
            this.triangle.clockLengthCounter();
            this.square1.clockLengthCounter();
            this.square2.clockLengthCounter();
            this.noise.clockLengthCounter();
            this.square1.clockSweep();
            this.square2.clockSweep();

        }

        if (this.derivedFrameCounter >= 0 && this.derivedFrameCounter < 4) {

            // Clock linear & decay:            
            this.square1.clockEnvDecay();
            this.square2.clockEnvDecay();
            this.noise.clockEnvDecay();
            this.triangle.clockLinearCounter();

        }
    
        if (this.derivedFrameCounter == 3 && this.countSequence==0) {
        
            // Enable IRQ:
            this.frameIrqActive = true;
        
        }
    
    
        // End of 240Hz tick
    
    }


    // Samples the channels, mixes the output together,
    // writes to buffer and (if enabled) file.
    void sample(){
        int sq_index, tnd_index;
        
        if (this.accCount > 0) {

            this.smpSquare1 <<= 4;
            this.smpSquare1 = (this.smpSquare1 / this.accCount).floor();

            this.smpSquare2 <<= 4;
            this.smpSquare2 = (this.smpSquare2 / this.accCount).floor();

            this.smpTriangle = (this.smpTriangle / this.accCount).floor();

            this.smpDmc <<= 4;
            this.smpDmc = (this.smpDmc / this.accCount).floor();
        
            this.accCount = 0;
        }
        else {
            this.smpSquare1 = this.square1.sampleValue << 4;
            this.smpSquare2 = this.square2.sampleValue << 4;
            this.smpTriangle = this.triangle.sampleValue;
            this.smpDmc = this.dmc.sample << 4;
        }
    
        int smpNoise = ((this.noise.accValue << 4) / 
                this.noise.accCount).floor();
        this.noise.accValue = smpNoise >> 4;
        this.noise.accCount = 1;

        // Stereo sound.
    
        // Left channel:
        sq_index  = (
                this.smpSquare1 * this.stereoPosLSquare1 + 
                this.smpSquare2 * this.stereoPosLSquare2
            ) >> 8;
        tnd_index = (
                3 * this.smpTriangle * this.stereoPosLTriangle + 
                (smpNoise<<1) * this.stereoPosLNoise + this.smpDmc * 
                this.stereoPosLDMC
            ) >> 8;
        if (sq_index >= this.square_table.length) {
            sq_index  = this.square_table.length-1;
        }
        if (tnd_index >= this.tnd_table.length) {
            tnd_index = this.tnd_table.length - 1;
        }
        int sampleValueL = this.square_table[sq_index] + 
                this.tnd_table[tnd_index] - this.dcValue;

        // Right channel:
        sq_index = (this.smpSquare1 * this.stereoPosRSquare1 +  
                this.smpSquare2 * this.stereoPosRSquare2
            ) >> 8;
        tnd_index = (3 * this.smpTriangle * this.stereoPosRTriangle + 
                (smpNoise << 1) * this.stereoPosRNoise + this.smpDmc * 
                this.stereoPosRDMC
            ) >> 8;
        if (sq_index >= this.square_table.length) {
            sq_index = this.square_table.length - 1;
        }
        if (tnd_index >= this.tnd_table.length) {
            tnd_index = this.tnd_table.length - 1;
        }
        int sampleValueR = this.square_table[sq_index] + 
                this.tnd_table[tnd_index] - this.dcValue;

        // Remove DC from left channel:
        int smpDiffL = sampleValueL - this.prevSampleL;
        this.prevSampleL += smpDiffL;
        this.smpAccumL += smpDiffL - (this.smpAccumL >> 10);
        sampleValueL = this.smpAccumL;
        
        // Remove DC from right channel:
        int smpDiffR     = sampleValueR - this.prevSampleR;
        this.prevSampleR += smpDiffR;
        this.smpAccumR  += smpDiffR - (this.smpAccumR >> 10);
        sampleValueR = this.smpAccumR;

        // Write:
        if (sampleValueL > this.maxSample) {
            this.maxSample = sampleValueL;
        }
        if (sampleValueL < this.minSample) {
            this.minSample = sampleValueL;
        }
        this.sampleBuffer[this.bufferIndex++] = sampleValueL;
        this.sampleBuffer[this.bufferIndex++] = sampleValueR;
        
        // Write full buffer
        if (this.bufferIndex == this.sampleBuffer.length) {
//            this.nes.ui.writeAudio(this.sampleBuffer);
            this.sampleBuffer = new List<int>(this.bufferSize*2);
            this.bufferIndex = 0;
        }

        // Reset sampled values:
        this.smpSquare1 = 0;
        this.smpSquare2 = 0;
        this.smpTriangle = 0;
        this.smpDmc = 0;

    }

    int getLengthMax(int value){
        return this.lengthLookup[value >> 3];
    }

    int getDmcFrequency(int value){
        if (value >= 0 && value < 0x10) {
            return this.dmcFreqLookup[value];
        }
        return 0;
    }

    int getNoiseWaveLength(int value){
        if (value >= 0 && value < 0x10) {
            return this.noiseWavelengthLookup[value];
        }
        return 0;
    }

    void setPanning(List<int> pos){
        for (int i = 0; i < 5; i++) {
            this.panning[i] = pos[i];
        }
        this.updateStereoPos();
    }

    void setMasterVolume(int value){
        if (value < 0) {
            value = 0;
        }
        if (value > 256) {
            value = 256;
        }
        this.masterVolume = value;
        this.updateStereoPos();
    }

    void updateStereoPos(){
        this.stereoPosLSquare1 = (this.panning[0] * this.masterVolume) >> 8;
        this.stereoPosLSquare2 = (this.panning[1] * this.masterVolume) >> 8;
        this.stereoPosLTriangle = (this.panning[2] * this.masterVolume) >> 8;
        this.stereoPosLNoise = (this.panning[3] * this.masterVolume) >> 8;
        this.stereoPosLDMC = (this.panning[4] * this.masterVolume) >> 8;
    
        this.stereoPosRSquare1 = this.masterVolume - this.stereoPosLSquare1;
        this.stereoPosRSquare2 = this.masterVolume - this.stereoPosLSquare2;
        this.stereoPosRTriangle = this.masterVolume - this.stereoPosLTriangle;
        this.stereoPosRNoise = this.masterVolume - this.stereoPosLNoise;
        this.stereoPosRDMC = this.masterVolume - this.stereoPosLDMC;
    }

    void initLengthLookup(){

        this.lengthLookup = [
            0x0A, 0xFE,
            0x14, 0x02,
            0x28, 0x04,
            0x50, 0x06,
            0xA0, 0x08,
            0x3C, 0x0A,
            0x0E, 0x0C,
            0x1A, 0x0E,
            0x0C, 0x10,
            0x18, 0x12,
            0x30, 0x14,
            0x60, 0x16,
            0xC0, 0x18,
            0x48, 0x1A,
            0x10, 0x1C,
            0x20, 0x1E
        ];
    }

    void initDmcFrequencyLookup(){

        this.dmcFreqLookup = new List<int>(16);

        this.dmcFreqLookup[0x0] = 0xD60;
        this.dmcFreqLookup[0x1] = 0xBE0;
        this.dmcFreqLookup[0x2] = 0xAA0;
        this.dmcFreqLookup[0x3] = 0xA00;
        this.dmcFreqLookup[0x4] = 0x8F0;
        this.dmcFreqLookup[0x5] = 0x7F0;
        this.dmcFreqLookup[0x6] = 0x710;
        this.dmcFreqLookup[0x7] = 0x6B0;
        this.dmcFreqLookup[0x8] = 0x5F0;
        this.dmcFreqLookup[0x9] = 0x500;
        this.dmcFreqLookup[0xA] = 0x470;
        this.dmcFreqLookup[0xB] = 0x400;
        this.dmcFreqLookup[0xC] = 0x350;
        this.dmcFreqLookup[0xD] = 0x2A0;
        this.dmcFreqLookup[0xE] = 0x240;
        this.dmcFreqLookup[0xF] = 0x1B0;
        //for(int i=0;i<16;i++)dmcFreqLookup[i]/=8;

    }

    void initNoiseWavelengthLookup(){

        this.noiseWavelengthLookup = new List<int>(16);

        this.noiseWavelengthLookup[0x0] = 0x004;
        this.noiseWavelengthLookup[0x1] = 0x008;
        this.noiseWavelengthLookup[0x2] = 0x010;
        this.noiseWavelengthLookup[0x3] = 0x020;
        this.noiseWavelengthLookup[0x4] = 0x040;
        this.noiseWavelengthLookup[0x5] = 0x060;
        this.noiseWavelengthLookup[0x6] = 0x080;
        this.noiseWavelengthLookup[0x7] = 0x0A0;
        this.noiseWavelengthLookup[0x8] = 0x0CA;
        this.noiseWavelengthLookup[0x9] = 0x0FE;
        this.noiseWavelengthLookup[0xA] = 0x17C;
        this.noiseWavelengthLookup[0xB] = 0x1FC;
        this.noiseWavelengthLookup[0xC] = 0x2FA;
        this.noiseWavelengthLookup[0xD] = 0x3F8;
        this.noiseWavelengthLookup[0xE] = 0x7F2;
        this.noiseWavelengthLookup[0xF] = 0xFE4;
    
    }

    void initDACtables(){
        double value;
        int ival, i;
        int max_sqr = 0;
        int max_tnd = 0;
        
        this.square_table = new List<int> (32*16);
        this.tnd_table = new List<int>(204*16);

        for (i = 0; i < 32 * 16; i++) {
            value = 95.52 / (8128.0 / (i/16.0) + 100.0);
            value *= 0.98411;
            value *= 50000.0;
            ival = value.floor();
        
            this.square_table[i] = ival;
            if (ival > max_sqr) {
                max_sqr = ival;
            }
        }
    
        for (i = 0; i < 204 * 16; i++) {
            value = 163.67 / (24329.0 / (i/16.0) + 100.0);
            value *= 0.98411;
            value *= 50000.0;
            ival = value.floor();
        
            this.tnd_table[i] = ival;
            if (ival > max_tnd) {
                max_tnd = ival;
            }

        }
    
        this.dacRange = max_sqr+max_tnd;
        this.dcValue = (this.dacRange/2).toInt();

    }
}


class JSNES_PAPU_ChannelDM {
  const int MODE_NORMAL = 0;
  const int MODE_LOOP = 1;
  const int MODE_IRQ = 2;
  
  JSNES_PAPU papu = null;
  
  bool isEnabled = false;
  bool hasSample = false;
  bool irqGenerated = false;
  
  int playMode;
  int dmaFrequency;
  int dmaCounter;
  int deltaCounter;
  int playStartAddress;
  int playAddress;
  int playLength;
  int playLengthCounter;
  int shiftCounter;
  int reg4012;
  int reg4013;
  int sample;
  int dacLsb;
  int data;
  
  JSNES_PAPU_ChannelDM(JSNES_PAPU papu) {
    this.papu = papu;
    
    this.reset();
  }
    
  void clockDmc() {
    
        // Only alter DAC value if the sample buffer has data:
        if(this.hasSample) {
        
            if ((this.data & 1) == 0) {
            
                // Decrement delta:
                if(this.deltaCounter>0) {
                    this.deltaCounter--;
                }
            }
            else {
                // Increment delta:
                if (this.deltaCounter < 63) {
                    this.deltaCounter++;
                }
            }
        
            // Update sample value:
            this.sample = this.isEnabled ? (this.deltaCounter << 1) + this.dacLsb : 0;
        
            // Update shift register:
            this.data >>= 1;
        
        }
    
        this.dmaCounter--;
        if (this.dmaCounter <= 0) {
        
            // No more sample bits.
            this.hasSample = false;
            this.endOfSample();
            this.dmaCounter = 8;
        
        }
    
        if (this.irqGenerated) {
            this.papu.nes.cpu.requestIrq(this.papu.nes.cpu.IRQ_NORMAL);
        }
    
    }

    void endOfSample() {
        if (this.playLengthCounter == 0 && this.playMode == this.MODE_LOOP) {
        
            // Start from beginning of sample:
            this.playAddress = this.playStartAddress;
            this.playLengthCounter = this.playLength;
        
        }
    
        if (this.playLengthCounter > 0) {
        
            // Fetch next sample:
            this.nextSample();
        
            if (this.playLengthCounter == 0) {
        
                // Last byte of sample fetched, generate IRQ:
                if (this.playMode == this.MODE_IRQ) {
                
                    // Generate IRQ:
                    this.irqGenerated = true;
                
                }
            
            }
        
        }
    
    }

    void nextSample() {
        // Fetch byte:
        this.data = this.papu.nes.mmap.load(this.playAddress);
        this.papu.nes.cpu.haltCycles(4);
    
        this.playLengthCounter--;
        this.playAddress++;
        if (this.playAddress > 0xFFFF) {
            this.playAddress = 0x8000;
        }
    
        this.hasSample = true;
    }

    void writeReg(int address, int value) {
        if (address == 0x4010) {
        
            // Play mode, DMA Frequency
            if ((value >> 6) == 0) {
                this.playMode = this.MODE_NORMAL;
            }
            else if (((value >> 6) & 1) == 1) {
                this.playMode = this.MODE_LOOP;
            }
            else if ((value >> 6) == 2) {
                this.playMode = this.MODE_IRQ;
            }
        
            if ((value & 0x80) == 0) {
                this.irqGenerated = false;
            }
        
            this.dmaFrequency = this.papu.getDmcFrequency(value & 0xF);
        
        }
        else if (address == 0x4011) {
        
            // Delta counter load register:
            this.deltaCounter = (value >> 1) & 63;
            this.dacLsb = value & 1;
            this.sample = ((this.deltaCounter << 1) + this.dacLsb); // update sample value
        
        }
        else if (address == 0x4012) {
        
            // DMA address load register
            this.playStartAddress = (value << 6) | 0x0C000;
            this.playAddress = this.playStartAddress;
            this.reg4012 = value;
        
        }
        else if (address == 0x4013) {
        
            // Length of play code
            this.playLength = (value << 4) + 1;
            this.playLengthCounter = this.playLength;
            this.reg4013 = value;
        
        }
        else if (address == 0x4015) {
        
            // DMC/IRQ Status
            if (((value >> 4) & 1) == 0) {
                // Disable:
                this.playLengthCounter = 0;
            }
            else {
                // Restart:
                this.playAddress = this.playStartAddress;
                this.playLengthCounter = this.playLength;
            }
            this.irqGenerated = false;
        }
    }

    void setEnabled(bool value) {
        if ((!this.isEnabled) && value) {
            this.playLengthCounter = this.playLength;
        }
        this.isEnabled = value;
    }

    int getLengthStatus() {
        return ((this.playLengthCounter == 0 || !this.isEnabled) ? 0 : 1);
    }

    int getIrqStatus(){
        return (this.irqGenerated ? 1 : 0);
    }

    void reset(){
        this.isEnabled = false;
        this.irqGenerated = false;
        this.playMode = this.MODE_NORMAL;
        this.dmaFrequency = 0;
        this.dmaCounter = 0;
        this.deltaCounter = 0;
        this.playStartAddress = 0;
        this.playAddress = 0;
        this.playLength = 0;
        this.playLengthCounter = 0;
        this.sample = 0;
        this.dacLsb = 0;
        this.shiftCounter = 0;
        this.reg4012 = 0;
        this.reg4013 = 0;
        this.data = 0;
    }
}


class JSNES_PAPU_ChannelNoise {
  JSNES_PAPU papu = null;
  
  bool isEnabled = false;
  bool envDecayDisable = false;
  bool envDecayLoopEnable = false;
  bool lengthCounterEnable = false;
  bool envReset = false;
  bool shiftNow = false;
  
  int lengthCounter = 0;
  int progTimerCount = 0;
  int progTimerMax = 0;
  int envDecayRate = 0;
  int envDecayCounter = 0;
  int envVolume = 0;
  int masterVolume = 0;
  int shiftReg = 0;
  int randomBit = 0;
  int randomMode = 0;
  int sampleValue = 0;
  int accValue;
  int accCount;
  int tmp = 0;
  
  JSNES_PAPU_ChannelNoise(JSNES_PAPU papu) {
    this.papu = papu;
    this.shiftReg = 1<<14;
    this.accValue=0;
    this.accCount=1;
    
    this.reset();
  }

  void reset() {
        this.progTimerCount = 0;
        this.progTimerMax = 0;
        this.isEnabled = false;
        this.lengthCounter = 0;
        this.lengthCounterEnable = false;
        this.envDecayDisable = false;
        this.envDecayLoopEnable = false;
        this.shiftNow = false;
        this.envDecayRate = 0;
        this.envDecayCounter = 0;
        this.envVolume = 0;
        this.masterVolume = 0;
        this.shiftReg = 1;
        this.randomBit = 0;
        this.randomMode = 0;
        this.sampleValue = 0;
        this.tmp = 0;
    }

    void clockLengthCounter(){
        if (this.lengthCounterEnable && this.lengthCounter>0){
            this.lengthCounter--;
            if (this.lengthCounter == 0) {
                this.updateSampleValue();
            }
        }
    }

    void clockEnvDecay() {
        if(this.envReset) {
            // Reset envelope:
            this.envReset = false;
            this.envDecayCounter = this.envDecayRate + 1;
            this.envVolume = 0xF;
        }
        else if (--this.envDecayCounter <= 0) {
            // Normal handling:
            this.envDecayCounter = this.envDecayRate + 1;
            if(this.envVolume>0) {
                this.envVolume--;
            }
            else {
                this.envVolume = this.envDecayLoopEnable ? 0xF : 0;
            }   
        }
        this.masterVolume = this.envDecayDisable ? this.envDecayRate : this.envVolume;
        this.updateSampleValue();
    }

    void updateSampleValue() {
        if (this.isEnabled && this.lengthCounter>0) {
            this.sampleValue = this.randomBit * this.masterVolume;
        }
    }

    void writeReg(int address, int value){
        if(address == 0x400C) {
            // Volume/Envelope decay:
            this.envDecayDisable = ((value&0x10) != 0);
            this.envDecayRate = value&0xF;
            this.envDecayLoopEnable = ((value&0x20) != 0);
            this.lengthCounterEnable = ((value&0x20)==0);
            this.masterVolume = this.envDecayDisable?this.envDecayRate:this.envVolume;
        
        }else if(address == 0x400E) {
            // Programmable timer:
            this.progTimerMax = this.papu.getNoiseWaveLength(value&0xF);
            this.randomMode = value>>7;
        
        }else if(address == 0x400F) {
            // Length counter
            this.lengthCounter = this.papu.getLengthMax(value&248);
            this.envReset = true;
        }
        // Update:
        //updateSampleValue();
    }

    void setEnabled(bool value){
        this.isEnabled = value;
        if (!value) {
            this.lengthCounter = 0;
        }
        this.updateSampleValue();
    }

    int getLengthStatus() {
        return ((this.lengthCounter==0 || !this.isEnabled)?0:1);
    }
}


class JSNES_PAPU_ChannelSquare {
  List<int> dutyLookup = [
                     0, 1, 0, 0, 0, 0, 0, 0,
                     0, 1, 1, 0, 0, 0, 0, 0,
                     0, 1, 1, 1, 1, 0, 0, 0,
                     1, 0, 0, 1, 1, 1, 1, 1
  ];
  
  List<int> impLookup = [
                    1,-1, 0, 0, 0, 0, 0, 0,
                    1, 0,-1, 0, 0, 0, 0, 0,
                    1, 0, 0, 0,-1, 0, 0, 0,
                    -1, 0, 1, 0, 0, 0, 0, 0
  ];
  
  JSNES_PAPU papu = null;
  
  bool isEnabled = false;
  bool lengthCounterEnable = false;
  bool sweepActive = false;
  bool envDecayDisable = false;
  bool envDecayLoopEnable = false;
  bool envReset = false;
  bool sweepCarry = false;
  bool updateSweepPeriod = false;
  
  int progTimerCount = 0;
  int progTimerMax = 0;
  int lengthCounter = 0;
  int squareCounter = 0;
  int sweepCounter = 0;
  int sweepCounterMax = 0;
  int sweepMode = 0;
  int sweepShiftAmount = 0;
  int envDecayRate = 0;
  int envDecayCounter = 0;
  int envVolume = 0;
  int masterVolume = 0;
  int dutyMode = 0;
  //var sweepResult = null;
  int sampleValue = 0;
  int vol = 0;
  bool sqr1 = false;
  
  JSNES_PAPU_ChannelSquare(JSNES_PAPU papu, bool square1) {
    this.papu = papu;
    this.sqr1 = square1;
    
    this.reset();
  }

  void reset() {
        this.progTimerCount = 0;
        this.progTimerMax = 0;
        this.lengthCounter = 0;
        this.squareCounter = 0;
        this.sweepCounter = 0;
        this.sweepCounterMax = 0;
        this.sweepMode = 0;
        this.sweepShiftAmount = 0;
        this.envDecayRate = 0;
        this.envDecayCounter = 0;
        this.envVolume = 0;
        this.masterVolume = 0;
        this.dutyMode = 0;
        this.vol = 0;
    
        this.isEnabled = false;
        this.lengthCounterEnable = false;
        this.sweepActive = false;
        this.sweepCarry = false;
        this.envDecayDisable = false;
        this.envDecayLoopEnable = false;
    }

    void clockLengthCounter() {
        if (this.lengthCounterEnable && this.lengthCounter > 0){
            this.lengthCounter--;
            if (this.lengthCounter == 0) {
                this.updateSampleValue();
            }
        }
    }

    void clockEnvDecay() {
        if (this.envReset) {
            // Reset envelope:
            this.envReset = false;
            this.envDecayCounter = this.envDecayRate + 1;
            this.envVolume = 0xF;
        }else if ((--this.envDecayCounter) <= 0) {
            // Normal handling:
            this.envDecayCounter = this.envDecayRate + 1;
            if (this.envVolume>0) {
                this.envVolume--;
            }else{
                this.envVolume = this.envDecayLoopEnable ? 0xF : 0;
            }
        }
    
        this.masterVolume = this.envDecayDisable ? this.envDecayRate : this.envVolume;
        this.updateSampleValue();
    }

    void clockSweep() {
        if (--this.sweepCounter<=0) {
        
            this.sweepCounter = this.sweepCounterMax + 1;
            if (this.sweepActive && this.sweepShiftAmount>0 && this.progTimerMax>7) {
            
                // Calculate result from shifter:
                this.sweepCarry = false;
                if (this.sweepMode==0) {
                    this.progTimerMax += (this.progTimerMax>>this.sweepShiftAmount);
                    if (this.progTimerMax > 4095) {
                        this.progTimerMax = 4095;
                        this.sweepCarry = true;
                    }
                }else{
                    this.progTimerMax = this.progTimerMax - ((this.progTimerMax>>this.sweepShiftAmount)-(this.sqr1?1:0));
                }
            }
        }
    
        if (this.updateSweepPeriod) {
            this.updateSweepPeriod = false;
            this.sweepCounter = this.sweepCounterMax + 1;
        }
    }

    void updateSampleValue() {
        if (this.isEnabled && this.lengthCounter>0 && this.progTimerMax>7) {
        
            if (this.sweepMode==0 && (this.progTimerMax + (this.progTimerMax>>this.sweepShiftAmount)) > 4095) {
            //if (this.sweepCarry) {
                this.sampleValue = 0;
            }else{
                this.sampleValue = this.masterVolume*this.dutyLookup[(this.dutyMode<<3)+this.squareCounter];    
            }
        }else{
            this.sampleValue = 0;
        }
    }

    void writeReg(int address, int value){
        int addrAdd = (this.sqr1?0:4);
        if (address == 0x4000 + addrAdd) {
            // Volume/Envelope decay:
            this.envDecayDisable = ((value&0x10) != 0);
            this.envDecayRate = value & 0xF;
            this.envDecayLoopEnable = ((value&0x20) != 0);
            this.dutyMode = (value>>6)&0x3;
            this.lengthCounterEnable = ((value&0x20)==0);
            this.masterVolume = this.envDecayDisable?this.envDecayRate:this.envVolume;
            this.updateSampleValue();
        
        }
        else if (address == 0x4001+addrAdd) {
            // Sweep:
            this.sweepActive = ((value&0x80) != 0);
            this.sweepCounterMax = ((value>>4)&7);
            this.sweepMode = (value>>3)&1;
            this.sweepShiftAmount = value&7;
            this.updateSweepPeriod = true;
        }
        else if (address == 0x4002+addrAdd){
            // Programmable timer:
            this.progTimerMax &= 0x700;
            this.progTimerMax |= value;
        }
        else if (address == 0x4003+addrAdd) {
            // Programmable timer, length counter
            this.progTimerMax &= 0xFF;
            this.progTimerMax |= ((value&0x7)<<8);
        
            if (this.isEnabled){
                this.lengthCounter = this.papu.getLengthMax(value&0xF8);
            }
        
            this.envReset  = true;
        }
    }

    void setEnabled(bool value) {
        this.isEnabled = value;
        if (!value) {
            this.lengthCounter = 0;
        }
        this.updateSampleValue();
    }

    int getLengthStatus() {
        return ((this.lengthCounter == 0 || !this.isEnabled) ? 0 : 1);
    }
}


class JSNES_PAPU_ChannelTriangle {
  JSNES_PAPU papu = null;
  
  bool isEnabled = false;
  bool sampleCondition = false;
  bool lengthCounterEnable = false;
  bool lcHalt = false;
  bool lcControl = false;
  
  int progTimerCount = 0;
  int progTimerMax = 0;
  int triangleCounter = 0;
  int lengthCounter = 0;
  int linearCounter = 0;
  int lcLoadValue = 0;
  int sampleValue = 0;
  int tmp = 0;
  
  JSNES_PAPU_ChannelTriangle(JSNES_PAPU papu) {
    this.papu = papu;    
    this.reset();
  }

  void reset(){
        this.progTimerCount = 0;
        this.progTimerMax = 0;
        this.triangleCounter = 0;
        this.isEnabled = false;
        this.sampleCondition = false;
        this.lengthCounter = 0;
        this.lengthCounterEnable = false;
        this.linearCounter = 0;
        this.lcLoadValue = 0;
        this.lcHalt = true;
        this.lcControl = false;
        this.tmp = 0;
        this.sampleValue = 0xF;
    }

    void clockLengthCounter(){
        if (this.lengthCounterEnable && this.lengthCounter>0) {
            this.lengthCounter--;
            if (this.lengthCounter==0) {
                this.updateSampleCondition();
            }
        }
    }

    void clockLinearCounter(){
        if (this.lcHalt){
            // Load:
            this.linearCounter = this.lcLoadValue;
            this.updateSampleCondition();
        }
        else if (this.linearCounter > 0) {
            // Decrement:
            this.linearCounter--;
            this.updateSampleCondition();
        }
        if (!this.lcControl) {
            // Clear halt flag:
            this.lcHalt = false;
        }
    }

    int getLengthStatus(){
        return ((this.lengthCounter == 0 || !this.isEnabled)?0:1);
    }

    void readReg(int address){
        return 0;
    }

    void writeReg(int address, int value){
        if (address == 0x4008) {
            // New values for linear counter:
            this.lcControl  = (value&0x80)!=0;
            this.lcLoadValue =  value&0x7F;
        
            // Length counter enable:
            this.lengthCounterEnable = !this.lcControl;
        }
        else if (address == 0x400A) {
            // Programmable timer:
            this.progTimerMax &= 0x700;
            this.progTimerMax |= value;
        
        }
        else if(address == 0x400B) {
            // Programmable timer, length counter
            this.progTimerMax &= 0xFF;
            this.progTimerMax |= ((value&0x07)<<8);
            this.lengthCounter = this.papu.getLengthMax(value&0xF8);
            this.lcHalt = true;
        }
    
        this.updateSampleCondition();
    }

    void clockProgrammableTimer(int nCycles){
        if (this.progTimerMax>0) {
            this.progTimerCount += nCycles;
            while (this.progTimerMax > 0 && 
                    this.progTimerCount >= this.progTimerMax) {
                this.progTimerCount -= this.progTimerMax;
                if (this.isEnabled && this.lengthCounter>0 && 
                        this.linearCounter > 0) {
                    this.clockTriangleGenerator();
                }
            }
        }
    }

    void clockTriangleGenerator() {
        this.triangleCounter++;
        this.triangleCounter &= 0x1F;
    }

    void setEnabled(bool value) {
        this.isEnabled = value;
        if(!value) {
            this.lengthCounter = 0;
        }
        this.updateSampleCondition();
    }

    void updateSampleCondition() {
        this.sampleCondition = this.isEnabled &&
                this.progTimerMax > 7 &&
                this.linearCounter > 0 &&
                this.lengthCounter > 0;
    }
}

