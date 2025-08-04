pub const OperationName = enum {
    MOV,
    ADD, 
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
    ADDRESS
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

pub const Operand = union(OperandType) {
    REGISTER: OperandRegister,
    IMMEDIATE: OperandImmediate,
    ADDRESS: OperandAddress
};

pub const Instruction = struct {
    name: OperationName,
    dest: Operand,
    source: Operand
};
