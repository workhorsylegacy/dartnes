/*
DartNES Copyright (c) 2013 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
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

library dartnes_keyboard;

// Keyboard events are bound in the UI
class Keyboard {
    Map<String, int> keys = null;
    List<int> state1 = null;
    List<int> state2 = null;
    
    Keyboard() {
        this.keys = {
        'KEY_A': 0,
        'KEY_B': 1,
        'KEY_SELECT': 2,
        'KEY_START': 3,
        'KEY_UP': 4,
        'KEY_DOWN': 5,
        'KEY_LEFT': 6,
        'KEY_RIGHT': 7
        };

        this.state1 = new List<int>.filled(8, 0);
        this.state2 = new List<int>.filled(8, 0);
        for(int i=0; i<8; i++) {
            this.state1[i] = 0x40;
            this.state2[i] = 0x40;
        }
    }
    
    bool setKey(int key, int value) {
        assert(key is int);
        assert(value is int);
        
        switch (key) {
            case 88: this.state1[this.keys['KEY_A']] = value; break;      // X
            case 89: this.state1[this.keys['KEY_B']] = value; break;      // Y (Central European keyboard)
            case 90: this.state1[this.keys['KEY_B']] = value; break;      // Z
            case 17: this.state1[this.keys['KEY_SELECT']] = value; break; // Right Ctrl
            case 13: this.state1[this.keys['KEY_START']] = value; break;  // Enter
            case 38: this.state1[this.keys['KEY_UP']] = value; break;     // Up
            case 40: this.state1[this.keys['KEY_DOWN']] = value; break;   // Down
            case 37: this.state1[this.keys['KEY_LEFT']] = value; break;   // Left
            case 39: this.state1[this.keys['KEY_RIGHT']] = value; break;  // Right

            case 103: this.state2[this.keys['KEY_A']] = value; break;     // Num-7
            case 105: this.state2[this.keys['KEY_B']] = value; break;     // Num-9
            case 99: this.state2[this.keys['KEY_SELECT']] = value; break; // Num-3
            case 97: this.state2[this.keys['KEY_START']] = value; break;  // Num-1
            case 104: this.state2[this.keys['KEY_UP']] = value; break;    // Num-8
            case 98: this.state2[this.keys['KEY_DOWN']] = value; break;   // Num-2
            case 100: this.state2[this.keys['KEY_LEFT']] = value; break;  // Num-4
            case 102: this.state2[this.keys['KEY_RIGHT']] = value; break; // Num-6
            default: return true;
        }
        return false; // preventDefault
    }

    void keyDown(evt) {
        if (!this.setKey(evt.keyCode, 0x41)) {
            evt.preventDefault();
        }
    }
    
    void keyUp(var evt) {
        if (!this.setKey(evt.keyCode, 0x40)) {
            evt.preventDefault();
        }
    }
    
    void keyPress(var evt) {
        evt.preventDefault();
    }
}
