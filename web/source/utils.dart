/*
DartNES Copyright (c) 2013 Matthew Brennan Jones <mattjones@workhorsy.org>
JSNes Copyright (C) 2010 Ben Firshman
vNES Copyright (C) 2006-2011 Jamie Sanders

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

library dartnes;
import 'dart:typed_data';

import 'ppu.dart';

class JSNES_Utils {    
    static void copyArrayElements(Int32List src, int srcPos, Int32List dest, int destPos, int length) {
        assert(src is Int32List);
        assert(srcPos is int);
        assert(dest is Int32List);
        assert(destPos is int);
        assert(length is int);
        
        for (int i = 0; i < length; ++i) {
            dest[destPos + i] = src[srcPos + i];
        }
    }
    
    static void copyTileElements(List<JSNES_PPU_Tile> src, int srcPos, List<JSNES_PPU_Tile> dest, int destPos, int length) {
      assert(src is List<JSNES_PPU_Tile>);
      assert(srcPos is int);
      assert(dest is List<JSNES_PPU_Tile>);
      assert(destPos is int);
      assert(length is int);
      
      for (int i = 0; i < length; ++i) {
        dest[destPos + i] = src[srcPos + i];
      }
    }
    
    /*
    static List<int> copyArray(List<int> src) {
        assert(src is List<int>);
        
        List<int> dest = new List<int>(src.length);
        for (int i = 0; i < src.length; i++) {
            dest[i] = src[i];
        }
        return dest;
    }
    */
/*
    static void fromJSON(obj, state) {
        for (var i = 0; i < obj.JSON_PROPERTIES.length; i++) {
            obj[obj.JSON_PROPERTIES[i]] = state[obj.JSON_PROPERTIES[i]];
        }
    }
    
    static String toJSON(obj) {
        var state = {};
        for (var i = 0; i < obj.JSON_PROPERTIES.length; i++) {
            state[obj.JSON_PROPERTIES[i]] = obj[obj.JSON_PROPERTIES[i]];
        }
        return state;
    }
*/
}

