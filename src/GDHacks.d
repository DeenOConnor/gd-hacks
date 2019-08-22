module GDHacks;

// By Deen O'Connor
// Thanks to Sonic for help

import std.stdio;
import core.sys.windows.windows;
import core.sys.windows.winuser;
import core.sys.windows.winbase;
import HackLib;
import std.string;
import std.conv;

GameProcess gameProc;
bool exit = false;

const uint BASE_MAGIC = 0x003222D0;
const uint NICKNAME_OFFSET = 0x198;
const uint LEVELID_OFFSET = 0x2A0;
const uint UBASE_OFFSET = 0x164; // Offset used for position and percentage
const uint GPOS_OFFSET = 0x224, XPOS_OFFSET = 0x67C, YPOS_OFFSET = 0x680; // GPOS is for getting X and Y
const uint PERC_OFFSET1 = 0x3C0, PERC_OFFSET2 = 0x12C; // 2 offsets for percentage

void main(string[] args) {
	connectToProcess();
    writeln("Welcome to Deen's GD Hacks\nType 'help' or '?' to get available commands");
	reqcmd();
}

void connectToProcess() {
	string[] modules = ["GeometryDash.exe", "libcocos2d.dll", "libcurl.dll"];
	gameProc = new GameProcess("GeometryDash.exe", "Geometry Dash", modules);
	gameProc.runOnProcess();
}

void reqcmd() {
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
			readPos(XPOS_OFFSET);
		break;
		case "get.ypos":
			readPos(YPOS_OFFSET);
		break;
		case "get.percentage":
			readPercent();
		break;
		case "set.xpos":
			write("Enter new X position: ");
			float newpos;
			try {
				newpos = to!float(readln().chop());
				writePos(XPOS_OFFSET, newpos);
			} catch (ConvException ex) {
				writeln("Invalid input!");
			}
		break;
		case "set.ypos":
			write("Enter new Y position: ");
			float newpos;
			try {
				newpos = to!float(readln().chop());
				writePos(YPOS_OFFSET, newpos);
			} catch (ConvException ex) {
				writeln("Invalid input!");
			}
		break;
		case "?":
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
	if (!exit) reqcmd();
}

void printHelp() {
	writeln(
"get.nickname  ----  print current nickname in game
get.levelid  ----  print current level id (-1 if not playing)
get.xpos  ----  print current X player position (-1 if not playing)
get.ypos  ----  print current Y player position (-1 if not playing)
get.percentage  ----  print current percentage on a level (-1 if not playing)
set.xpos  ----  set current X player position (does nothing if not playing)
set.ypos  ----  set current Y player position (does nothing if not playing)
help, ?  ----  print this help
exit  ----  exit the program");
}

// READING VALUES

void readNickname() {
	uint pointerValue;
	pointerValue = getPointerValue(gameProc.processModules["GeometryDash.exe"], BASE_MAGIC);
	printMemString(pointerValue + NICKNAME_OFFSET);
}

void readLevelid() {
	uint pointerValue, levelid;
	pointerValue = getPointerValue(gameProc.processModules["GeometryDash.exe"], BASE_MAGIC);
	if (getPointerValue(pointerValue, UBASE_OFFSET) == 0) {
		writeln(-1);
		return;
	}
	ReadProcessMemory(gameProc.processHandle, cast(PVOID)(pointerValue + LEVELID_OFFSET), &levelid, uint.sizeof, null);
	writeln(levelid);
}

void readPos(uint oof) { // Using specific offset because X and Y only differ by 4 bytes
	uint ptr0, ptr1, ptr2;
	ptr0 = getPointerValue(gameProc.processModules["GeometryDash.exe"], BASE_MAGIC);
	ptr1 = getPointerValue(ptr0, UBASE_OFFSET);
	if (ptr1 == 0) {
		writeln(-1);
		return;
	}
	ptr2 = getPointerValue(ptr1, GPOS_OFFSET);
	
	float position = -1;
	ReadProcessMemory(gameProc.processHandle, cast(PVOID)(ptr2 + oof), &position, uint.sizeof, null);
	writeln(position);
}

void readPercent() {
	uint ptr0, ptr1, ptr2; //BASE_MAGIC -> UBASE_OFFSET -> PERC_OFFSETs 1 and 2
	ptr0 = getPointerValue(gameProc.processModules["GeometryDash.exe"], BASE_MAGIC);
	ptr1 = getPointerValue(ptr0, UBASE_OFFSET);
	if (ptr1 == 0) {
		writeln(-1);
		return;
	}
	ptr2 = getPointerValue(ptr1, PERC_OFFSET1);
	printMemString(ptr2 + PERC_OFFSET2);
}

// WRITING VALUES

void writePos(uint oof, float newpos) {
	uint ptr0, ptr1, ptr2;
	ptr0 = getPointerValue(gameProc.processModules["GeometryDash.exe"], BASE_MAGIC);
	ptr1 = getPointerValue(ptr0, UBASE_OFFSET);
	if (ptr1 == 0) {
		writeln("Not on a level");
		return;
	}
	ptr2 = getPointerValue(ptr1, GPOS_OFFSET);

	WriteProcessMemory(gameProc.processHandle, cast(PVOID)(ptr2 + oof), &newpos, float.sizeof, null);
}

// HELPER FUNCTIONS

uint getPointerValue(uint base, uint offset) { // Very useful thing
	uint pointerValue = 0;
	ReadProcessMemory(gameProc.processHandle, cast(PVOID)(base + offset), &pointerValue, uint.sizeof, null); // Reading pointer value
	return pointerValue;
}

void printMemString(uint address) {
	char[15] buf; // Typically there are max 15 chars. Will be (probably) updated later
	ReadProcessMemory(gameProc.processHandle, cast(PVOID) address, &buf, char.sizeof*15, null); // Reading the nickname itself
	string nickname = cast(string) buf;
	int index = nickname.indexOf(0x00);
	if (index != -1) 
		nickname = nickname[0..index]; // Getting rid of garbage bytes that sometimes make it to this memory region
	writeln(nickname);
}
