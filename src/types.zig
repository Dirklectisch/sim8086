pub const OperationName = enum {
    MOV,
    ADD,
    SUB,
    CMP,
    JNZ
};

pub const Register = enum {
    AX,
    AL,
    AH,
    BX,
    BL,
    BH,
    CX,
    CL,
    CH,
    DX,
    DL,
    DH,
    SP,
    BP,
    SI,
    DI,
};

pub const OperandType = enum {
    REGISTER,
    IMMEDIATE,
    ADDRESS,
    TARGET
};

pub const OperandRegister = struct {
    target: Register
};

pub const OperandImmediate = struct {
    value: i16
};

pub const OperandAddress = struct {
    registers: [2]?Register,
    value: ?i16,
};

pub const OperandTarget = struct {
    value: i8
};

pub const Operand = union(OperandType) {
    REGISTER: OperandRegister,
    IMMEDIATE: OperandImmediate,
    ADDRESS: OperandAddress,
    TARGET: OperandTarget
};

pub const Size = enum {
    BYTE,
    WORD,
    UNKNOWN,
};

pub const Instruction = struct {
    name: OperationName,
    dest: Operand,
    source: Operand,
    size: Size
};
