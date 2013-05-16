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

class JSNES_Utils {
    static void copyArrayElements(List src, int srcPos, List dest, int destPos, int length) {
        for (int i = 0; i < length; ++i) {
            dest[destPos + i] = src[srcPos + i];
        }
    }
    
    static List copyArray(List src) {
        var dest = new List(src.length);
        for (int i = 0; i < src.length; i++) {
            dest[i] = src[i];
        }
        return dest;
    }
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

    static bool isIE() {
        return (/msie/i.test(navigator.userAgent) && !/opera/i.test(navigator.userAgent));
    }
*/
}

