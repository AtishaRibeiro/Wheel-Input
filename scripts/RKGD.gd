extends Object

# This code was translated from Thakis' C++ Yaz0 decoder into GDScript

class_name RKGD

var total_frames = 0
var face_inputs = []
var analog_inputs = []
var trick_inputs = []
var face_start_indices = []
var analog_start_indices = []
var trick_start_indices = []
var file_loaded = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	
func load_file(path):
	var file = File.new()
	file.open(path, File.READ)
	var content = file.get_buffer(file.get_len())
	file.close()
	var inputs = self.DecodeYaz1(content)
	set_inputs(inputs)
	self.file_loaded = true
	
func reset():
	pass
	
func get_neutral_input():
	return {
		"active": false,
		"a_button": false,
		"b_button": false,
		"l_trigger": false,
		"analog": [0.5, 0.5],
		"trick": "None"
	}
	
func get_input(current_frame):
	if current_frame >= self.total_frames or !self.file_loaded:
		return get_neutral_input()

	var face_index = 0
	var analog_index = 0
	var trick_index = 0

	while current_frame > self.face_start_indices[face_index]:
		face_index += 1

	while current_frame > self.analog_start_indices[analog_index]:
		analog_index += 1

	while current_frame > self.trick_start_indices[trick_index]:
		trick_index += 1

	var actions = self.face_inputs[face_index]
	var coords = self.analog_inputs[analog_index]
	var trick = self.trick_inputs[trick_index]

	return {
	"active": true,
	"a_button": actions[0],
	"b_button": actions[1],
	"l_trigger": actions[2],
	"analog": coords,
	"trick": trick
	}
	
func set_inputs(raw_inputs):
	var nr_face_inputs = (raw_inputs[0] << 0x08) | raw_inputs[1]
	var nr_analog_inputs = (raw_inputs[2] << 0x08) | raw_inputs[3]
	var nr_trick_inputs = (raw_inputs[4] << 0x08) | raw_inputs[5]
	var current_byte = 8
	self.face_inputs = []
	self.analog_inputs = []
	self.trick_inputs = []
	self.face_start_indices = []
	self.analog_start_indices = []
	self.trick_start_indices = []
	
	var endFrame = 0
	for _i in range(nr_face_inputs):
		var inputs = raw_inputs[current_byte]
		var duration = raw_inputs[current_byte + 1]
		var accelerator = (inputs & 0x01) != 0
		var drift = (inputs & 0x02) != 0
		var item = (inputs & 0x04) != 0

		endFrame += duration
		self.face_start_indices.push_back(endFrame)
		self.face_inputs.push_back([accelerator, drift, item])

		current_byte += 2

	self.total_frames = endFrame

	endFrame = 0
	for _i in range(nr_analog_inputs):
		var inputs = raw_inputs[current_byte]
		var duration = raw_inputs[current_byte + 1]
		var vertical = inputs & 0x0F
		var horizontal = (inputs >> 4) & 0x0F

		endFrame += duration
		self.analog_start_indices.push_back(endFrame)
		self.analog_inputs.push_back([horizontal / 14.0, vertical / 14.0])

		current_byte += 2

	endFrame = 0
	var tricks = {0: "None", 1: "Up", 2: "Down", 3: "Left", 4: "Right"}
	for _i in range(nr_trick_inputs):
		var inputs = raw_inputs[current_byte]
		var duration = raw_inputs[current_byte + 1]
		var trick = tricks[(inputs & 0x70) >> 16]
		var fullBytePresses = inputs & 0x0F

		# fullBytePresses specifies how many times 255 frames was spent idling before the current action
		for _j in range(fullBytePresses):
			endFrame += 256
			self.trick_start_indices.push_back(endFrame)
			self.trick_inputs.push_back(0)

		endFrame += duration
		self.trick_start_indices.push_back(endFrame)
		self.trick_inputs.push_back(trick)

		current_byte += 2


func DecodeYaz1(src):
	var readBytes = 0
	var srcSize = src.size()
	print("input file size: 0x%x\n" % srcSize)
	var decodedBytes = PoolByteArray()

	while readBytes < srcSize:
		# search yaz1 block
		var start_text = src.subarray(readBytes, readBytes + 3)
		while readBytes + 3 < srcSize and start_text.get_string_from_ascii() != "Yaz1":
			readBytes += 1
			start_text = src.subarray(readBytes, readBytes + 3)

		if readBytes + 3 >= srcSize:
			return decodedBytes # nothing left to decode

		readBytes += 4

		var og = src.subarray(readBytes, readBytes + 3)
		var size = (og[0] << 24) + (og[1] << 16) + (og[2] << 8) + og[3]
		readBytes += 12; # 4 byte size, 8 byte unused
		decodedBytes = _decode_Yaz1(src, readBytes, size)
		print("uncompressed is 0x%x bytes" % size)
		print("Read 0x%x bytes from input\n" % decodedBytes.size())

	return decodedBytes;

func _decode_Yaz1(src, offset, uncompressedSize):
	var srcPos = offset
	var validBitCount = 0 # number of valid bits left in "code" byte
	var currCodeByte = src[offset + srcPos]
	var dst = PoolByteArray()
	
	while dst.size() < uncompressedSize:
		# read new "code" byte if the current one is used up
		if validBitCount == 0:
			currCodeByte = src[srcPos]
			srcPos += 1
			validBitCount = 8

		if (currCodeByte & 0x80) != 0:
			# straight copy
			dst.push_back(src[srcPos])
			srcPos += 1
		else:
			# RLE part
			var byte1 = src[srcPos]
			var byte2 = src[srcPos + 1]
			srcPos += 2

			var dist = ((byte1 & 0xF) << 8) | byte2
			var copySource = dst.size() - (dist + 1)

			var numBytes = byte1 >> 4
			if numBytes == 0:
				numBytes = src[srcPos] + 0x12
				srcPos += 1
			else:
				numBytes += 2;

			# copy run
			for _i in range(numBytes):
				dst.push_back(dst[copySource])
				copySource += 1

		# use next bit from "code" byte
		currCodeByte <<= 1
		validBitCount -= 1

	return dst

