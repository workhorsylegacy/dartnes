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

import 'mappers.dart';
import 'nes.dart';
import 'ppu.dart';

class JSNES_ROM {
  // Mirroring types:
  const int VERTICAL_MIRRORING = 0;
  const int HORIZONTAL_MIRRORING = 1;
  const int FOURSCREEN_MIRRORING = 2;
  const int SINGLESCREEN_MIRRORING = 3;
  const int SINGLESCREEN_MIRRORING2 = 4;
  const int SINGLESCREEN_MIRRORING3 = 5;
  const int SINGLESCREEN_MIRRORING4 = 6;
  const int CHRROM_MIRRORING = 7;
  
  JSNES_NES nes = null;
  List<String> mapperName = null;
  List<int> header = null;
  List<List<int>> rom = null;
  List<List<int>> vrom = null;
  List<int> saveRam = null;
  List<List<JSNES_PPU_Tile>> vromTile = null;
  
  int romCount = 0;
  int vromCount = 0;
  int mirroring = 0;
  bool batteryRam = false;
  bool trainer = false;
  bool fourScreen = false;
  int mapperType = 0;
  bool valid = false;
  
  JSNES_ROM(JSNES_NES nes) {
    this.nes = nes;
    
    this.mapperName = new List<String>(92);
    
    for (int i=0;i<92;i++) {
        this.mapperName[i] = "Unknown Mapper";
    }
    this.mapperName[ 0] = "Direct Access";
    this.mapperName[ 1] = "Nintendo MMC1";
    this.mapperName[ 2] = "UNROM";
    this.mapperName[ 3] = "CNROM";
    this.mapperName[ 4] = "Nintendo MMC3";
    this.mapperName[ 5] = "Nintendo MMC5";
    this.mapperName[ 6] = "FFE F4xxx";
    this.mapperName[ 7] = "AOROM";
    this.mapperName[ 8] = "FFE F3xxx";
    this.mapperName[ 9] = "Nintendo MMC2";
    this.mapperName[10] = "Nintendo MMC4";
    this.mapperName[11] = "Color Dreams Chip";
    this.mapperName[12] = "FFE F6xxx";
    this.mapperName[15] = "100-in-1 switch";
    this.mapperName[16] = "Bandai chip";
    this.mapperName[17] = "FFE F8xxx";
    this.mapperName[18] = "Jaleco SS8806 chip";
    this.mapperName[19] = "Namcot 106 chip";
    this.mapperName[20] = "Famicom Disk System";
    this.mapperName[21] = "Konami VRC4a";
    this.mapperName[22] = "Konami VRC2a";
    this.mapperName[23] = "Konami VRC2a";
    this.mapperName[24] = "Konami VRC6";
    this.mapperName[25] = "Konami VRC4b";
    this.mapperName[32] = "Irem G-101 chip";
    this.mapperName[33] = "Taito TC0190/TC0350";
    this.mapperName[34] = "32kB ROM switch";
    
    this.mapperName[64] = "Tengen RAMBO-1 chip";
    this.mapperName[65] = "Irem H-3001 chip";
    this.mapperName[66] = "GNROM switch";
    this.mapperName[67] = "SunSoft3 chip";
    this.mapperName[68] = "SunSoft4 chip";
    this.mapperName[69] = "SunSoft5 FME-7 chip";
    this.mapperName[71] = "Camerica chip";
    this.mapperName[78] = "Irem 74HC161/32-based";
    this.mapperName[91] = "Pirate HK-SF3 chip";
  }
    
    void load(String data) {
        assert(data is String);
        
        int i, j, v;
        
        if (data.indexOf("NES\x1a") == -1) {
            this.nes.ui.updateStatus("Not a valid NES ROM.");
            return;
        }
        this.header = new List<int>.filled(16, 0);
        for (i = 0; i < 16; i++) {
            this.header[i] = data.codeUnitAt(i) & 0xFF;
        }
        this.romCount = this.header[4];
        this.vromCount = this.header[5]*2; // Get the number of 4kB banks, not 8kB
        this.mirroring = ((this.header[6] & 1) != 0 ? 1 : 0);
        this.batteryRam = (this.header[6] & 2) != 0;
        this.trainer = (this.header[6] & 4) != 0;
        this.fourScreen = (this.header[6] & 8) != 0;
        this.mapperType = (this.header[6] >> 4) | (this.header[7] & 0xF0);

        if (this.saveRam == null)
            this.saveRam = new List<int>.filled(0x2000, 0);
        // Check whether byte 8-15 are zero's:
        bool foundError = false;
        for (i=8; i<16; i++) {
            if (this.header[i] != 0) {
                foundError = true;
                break;
            }
        }
        if (foundError) {
            this.mapperType &= 0xF; // Ignore byte 7
        }
        // Load PRG-ROM banks:
        this.rom = new List<List<int>>(this.romCount);
        int offset = 16;
        for (i=0; i < this.romCount; i++) {
            this.rom[i] = new List<int>.filled(16384, 0);
            for (j=0; j < 16384; j++) {
                if (offset+j >= data.length) {
                    break;
                }
                this.rom[i][j] = data.codeUnitAt(offset + j) & 0xFF;
            }
            offset += 16384;
        }
        // Load CHR-ROM banks:
        this.vrom = new List<List<int>>(this.vromCount);
        for (i=0; i < this.vromCount; i++) {
            this.vrom[i] = new List<int>.filled(4096, 0);
            for (j=0; j < 4096; j++) {
                if (offset+j >= data.length){
                    break;
                }
                this.vrom[i][j] = data.codeUnitAt(offset + j) & 0xFF;
            }
            offset += 4096;
        }
        
        // Create VROM tiles:
        this.vromTile = new List<List<JSNES_PPU_Tile>>(this.vromCount);
        for (i=0; i < this.vromCount; i++) {
            this.vromTile[i] = new List<JSNES_PPU_Tile>(256);
            for (j=0; j < 256; j++) {
                this.vromTile[i][j] = new JSNES_PPU_Tile();
            }
        }
        
        // Convert CHR-ROM banks to tiles:
        int tileIndex;
        int leftOver;
        for (v=0; v < this.vromCount; v++) {
            for (i=0; i < 4096; i++) {
                tileIndex = i >> 4;
                leftOver = i % 16;
                if (leftOver < 8) {
                    this.vromTile[v][tileIndex].setScanline(
                        leftOver,
                        this.vrom[v][i],
                        this.vrom[v][i+8]
                    );
                }
                else {
                    this.vromTile[v][tileIndex].setScanline(
                        leftOver-8,
                        this.vrom[v][i-8],
                        this.vrom[v][i]
                    );
                }
            }
        }
        
        this.valid = true;
    }
    
    int getMirroringType() {
        if (this.fourScreen) {
            return this.FOURSCREEN_MIRRORING;
        }
        if (this.mirroring == 0) {
            return this.HORIZONTAL_MIRRORING;
        }
        return this.VERTICAL_MIRRORING;
    }
    
    String getMapperName() {
        if (this.mapperType >= 0 && this.mapperType < this.mapperName.length) {
            return this.mapperName[this.mapperType];
        }
        return "Unknown Mapper, "+this.mapperType;
    }
    
    bool mapperSupported() {
      return [0, 1, 2].contains(this.mapperType);
    }
    
    JSNES_MapperDefault createMapper() {
        if (this.mapperSupported()) {
            switch(this.mapperType) {
              case 0: return new JSNES_MapperDefault(this.nes);
              case 1: return new JSNES_Mapper_1(this.nes);
              case 2: return new JSNES_Mapper_2(this.nes);
            }
        }
        else {
            this.nes.ui.updateStatus("This ROM uses a mapper not supported by JSNES: "+this.getMapperName()+"("+this.mapperType.toString()+")");
            return null;
        }
    }
}
