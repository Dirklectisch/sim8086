pub const OperationName = enum {
    MOV,
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
    IMMEDIATE
};

pub const OperandRegister = struct {
    target: Register
};

pub const OperandImmediate = struct {
    value: i16
};

pub const Operand = union(OperandType) {
    REGISTER: OperandRegister,
    IMMEDIATE: OperandImmediate
};

pub const Instruction = struct {
    name: OperationName,
    dest: Operand,
    source: Operand
};
