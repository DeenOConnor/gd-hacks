module GDHacks;

// By Deen O'Connor

pragma(lib, "user32");

import std.stdio;
import core.sys.windows.windows;
import core.sys.windows.winuser;
import core.sys.windows.winbase;
import HackLib;
import std.string;
import std.conv;

GameProcess gameProc;
bool exit = false;

// Base offset to start looking for data
const uint off_magic = 0x003222D0;
const uint off_nickname = 0x198;
const uint off_levelid = 0x2A0;

// Offset used for position, percentage and check if a level is played
const uint off_ubase = 0x164;

// First is most likely a pointer to a structure, other two are for getting X and Y
const uint off_position = 0x224, off_xpos = 0x67C, off_ypos = 0x680; 

// 2 offsets for percentage
const uint off_perc1 = 0x3C0, off_perc2 = 0x12C; 

// It's easier to have this assigned as a global variable
ubyte* ptr_magicStart = null;

void main(string[] args) {
    string[] modules = ["GeometryDash.exe"];
    gameProc = new GameProcess("GeometryDash.exe", "Geometry Dash", modules);
    gameProc.runOnProcess();

    ReadProcessMemory(gameProc.processHandle, gameProc.processModules["GeometryDash.exe"] + off_magic, cast(void*)&ptr_magicStart, (ubyte*).sizeof, null);
    if (ptr_magicStart is null) {
        writeln("Something went wrong, try restarting the program.");
        readln();
        return;
    }

    writeln("Welcome to Deen's GD Hacks\nType 'help' or '?' to get available commands");
    reqcmd();
}

void reqcmd() {
    while (!exit) {
        write("> ");
        string command = readln().chop();

        switch (command) {
            case "get.nickname":
                readNickname();
            break;
            case "get.levelid":
                readLevelid();
            break;
            case "get.xpos":
                readPos(off_xpos);
            break;
            case "get.ypos":
                readPos(off_ypos);
            break;
            case "get.percentage":
                readPercent();
            break;
            case "set.xpos":
                write("Enter new X position: ");
                float newpos;
                try {
                    newpos = to!float(readln().chop());
                    writePos(off_xpos, newpos);
                } catch (ConvException ex) {
                    writeln("Invalid input!");
                }
            break;
            case "set.ypos":
                write("Enter new Y position: ");
                float newpos;
                try {
                    newpos = to!float(readln().chop());
                    writePos(off_ypos, newpos);
                } catch (ConvException ex) {
                    writeln("Invalid input!");
                }
            break;
            case "?":
                goto case "help";
            case "help":
                printHelp();
            break;
            case "exit":
                exit = true;
            break;
            default:
                writeln("Command not recognized!");
            break;
        }
    }
}

void printHelp() {
    writeln(
            "get.nickname  ----  print current nickname in game
            get.levelid  ----  print current level id (or a note if not playing)
            get.xpos  ----  print current X player position (or a note if not playing)
            get.ypos  ----  print current Y player position (or a note if not playing)
            get.percentage  ----  print current percentage (takes the value from GUI)
            set.xpos  ----  set current X player position (does nothing if not playing)
            set.ypos  ----  set current Y player position (does nothing if not playing)
            help, ?  ----  print this help
            exit  ----  exit the program");
}

// --------------
// READING VALUES
// --------------

void readNickname() {
    //off_magic -> off_nickname
    printMemString(ptr_magicStart + off_nickname);
}

void readLevelid() {
    //off_magic -> off_levelid
    uint levelid, ubaseCheck;
    ReadProcessMemory(gameProc.processHandle, ptr_magicStart + off_ubase, &ubaseCheck, uint.sizeof, null);
    if (ubaseCheck == 0) {
        // 0 at ubase means we are not currently on a level
        writeln("Not on a level");
        return;
    }
    ReadProcessMemory(gameProc.processHandle, ptr_magicStart + off_levelid, &levelid, uint.sizeof, null);
    writeln(levelid);
}

void readPos(uint oof) { // Passing offset as argument because X and Y are next to each other
    //off_magic -> off_ubase -> off_position -> off_xpos or off_ypos
    ubyte* ptr_ubase, ptr_position;
    ReadProcessMemory(gameProc.processHandle, ptr_magicStart + off_ubase, &ptr_ubase, (void*).sizeof, null);
    if (ptr_ubase is null) {
        writeln("Not on a level");
        return;
    }

    ReadProcessMemory(gameProc.processHandle, ptr_ubase + off_position, &ptr_position, (void*).sizeof, null);
    if (ptr_position is null) {
        writeln("Can't get to position address");
        return;
    }

    float position = -1;
    ReadProcessMemory(gameProc.processHandle, ptr_position + oof, &position, float.sizeof, null);
    writeln(position);
}

void readPercent() {
    //off_magic -> off_ubase -> off_perc1 -> off_perc2
    ubyte* ptr_ubase, ptr_percentage;
    ReadProcessMemory(gameProc.processHandle, ptr_magicStart + off_ubase, &ptr_ubase, (void*).sizeof, null);
    if (ptr_ubase is null) {
        writeln("Not on a level");
        return;
    }

    ReadProcessMemory(gameProc.processHandle, ptr_ubase + off_perc1, &ptr_percentage, (void*).sizeof, null);
    if (ptr_percentage is null) {
        writeln("Can't get to percentage address");
        return;
    }

    printMemString(ptr_percentage + off_perc2);
}

// --------------
// WRITING VALUES
// --------------

void writePos(uint oof, float newpos) {
    //off_magic -> off_ubase -> off_position -> off_xpos or off_ypos
    ubyte* ptr_ubase, ptr_position;
    ReadProcessMemory(gameProc.processHandle, ptr_magicStart + off_ubase, &ptr_ubase, (void*).sizeof, null);
    if (ptr_ubase is null) {
        writeln("Not on a level");
        return;
    }

    ReadProcessMemory(gameProc.processHandle, ptr_ubase + off_position, &ptr_position, (void*).sizeof, null);
    if (ptr_position is null) {
        writeln("Can't get to position address");
        return;
    }

    WriteProcessMemory(gameProc.processHandle, ptr_position + oof, &newpos, float.sizeof, null);
}

// ----------------
// HELPER FUNCTIONS
// ----------------

void printMemString(void* address) {
    // Typically there are max 15 chars. Will be (probably) updated later
    char[15] buf; 
    ReadProcessMemory(gameProc.processHandle, address, &buf, char.sizeof*15, null);
    string nickname = cast(string) buf;
    int index = nickname.indexOf(0x00);
    if (index != -1) {
         // Getting rid of garbage bytes that sometimes make it to this memory region
        nickname = nickname[0..index];
    }
    writeln(nickname);
}
